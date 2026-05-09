import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _uuid = Uuid();
final _random = Random();

/// Represents a connected device
class ConnectedDevice {
  final String id;
  final String name;
  final String deviceType;
  final String pairCode;
  final WebSocketChannel channel;
  DateTime lastPing;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.pairCode,
    required this.channel,
    DateTime? lastPing,
  }) : lastPing = lastPing ?? DateTime.now();

  Map<String, dynamic> toJson({String status = 'online'}) => {
        'id': id,
        'name': name,
        'type': deviceType,
        'status': status,
        'lastSeen': lastPing.toIso8601String(),
      };
}

/// Signaling server managing device connections
class SignalingServer {
  final Map<String, ConnectedDevice> _devices = {};
  final Map<String, String> _pairCodeToDeviceId = {};
  final Map<String, List<Map<String, dynamic>>> _pendingMessages = {};
  Timer? _cleanupTimer;
  static const int _maxPendingMessages = 50;
  static const Duration _cleanupInterval = Duration(seconds: 30);
  static const Duration _staleThreshold = Duration(seconds: 90);

  /// Generate a unique 6-digit pairing code
  String _generatePairCode() {
    String code;
    do {
      code = (_random.nextInt(900000) + 100000).toString();
    } while (_pairCodeToDeviceId.containsKey(code));
    return code;
  }

  /// Start periodic cleanup of stale devices
  void startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanStaleDevices();
    });
  }

  /// Remove devices that haven't pinged within the stale threshold
  void _cleanStaleDevices() {
    final now = DateTime.now();
    final staleIds = _devices.entries
        .where((e) => now.difference(e.value.lastPing) > _staleThreshold)
        .map((e) => e.key)
        .toList();

    for (final id in staleIds) {
      print('[CLEANUP] Removing stale device: $id');
      _handleDisconnect(id);
    }
  }

  /// Forward a message to the receiver, or notify sender if offline
  void _forwardToReceiver(String? senderId, Map<String, dynamic> message,
      {String? resolvedReceiverId}) {
    if (senderId == null) return;

    final receiverId = message['receiverId'] as String?;
    if (receiverId == null) return;

    final targetId = resolvedReceiverId ?? receiverId;
    final receiver = _devices[targetId];

    if (receiver != null) {
      _send(receiver.channel, message);
      print('[FORWARD] ${message['type']} from $senderId to $targetId');
    } else {
      _sendDeviceOffline(senderId, targetId);
      _storePendingMessage(targetId, message);
      print('[WARN] Device $targetId not found, message queued');
    }
  }

  /// Dispose server resources
  void dispose() {
    _cleanupTimer?.cancel();
  }

  /// Handle a new WebSocket connection
  void onConnection(WebSocketChannel channel) {
    String? deviceId;

    channel.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          final type = message['type'] as String?;

          if (type == null) {
            _sendError(channel, 'Missing message type');
            return;
          }

          switch (type) {
            case 'register':
              deviceId = _handleRegister(channel, message);
              break;
            case 'ping':
              _handlePing(deviceId, channel);
              break;
            case 'offer':
            case 'answer':
            case 'iceCandidate':
              _handleSignaling(deviceId, message);
              break;
            case 'pairRequest':
              _handlePairRequest(deviceId, message);
              break;
            case 'pairResponse':
              _handlePairResponse(deviceId, message);
              break;
            case 'relayMessage':
            case 'relayFileStart':
            case 'relayFileChunk':
            case 'relayFileEnd':
            case 'relayClipboard':
              _forwardToReceiver(deviceId, message);
              break;
            default:
              _sendError(channel, 'Unknown message type: $type');
          }
        } catch (e) {
          _sendError(channel, 'Invalid message format: $e');
        }
      },
      onDone: () {
        if (deviceId != null) {
          _handleDisconnect(deviceId!);
        }
      },
      onError: (error) {
        if (deviceId != null) {
          _handleDisconnect(deviceId!);
        }
      },
    );
  }

  /// Handle device registration
  String _handleRegister(
      WebSocketChannel channel, Map<String, dynamic> message) {
    final data = message['data'] as Map<String, dynamic>?;
    final deviceId = message['senderId'] as String? ?? _uuid.v4();
    final deviceName = data?['name'] as String? ?? 'Unknown Device';
    final deviceType = data?['deviceType'] as String? ?? 'desktop';

    // Generate pairing code
    final pairCode = _generatePairCode();

    // Remove old pairing code if device re-registers
    final oldDevice = _devices[deviceId];
    if (oldDevice != null) {
      _pairCodeToDeviceId.remove(oldDevice.pairCode);
    }

    _devices[deviceId] = ConnectedDevice(
      id: deviceId,
      name: deviceName,
      deviceType: deviceType,
      pairCode: pairCode,
      channel: channel,
    );
    _pairCodeToDeviceId[pairCode] = deviceId;

    // Send registration acknowledgement with pairing code
    _send(channel, {
      'type': 'registerAck',
      'senderId': 'server',
      'receiverId': deviceId,
      'data': {
        'deviceId': deviceId,
        'pairCode': pairCode,
        'success': true,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Send current device list to the new device
    _sendDeviceList(channel);

    // Notify other devices about the new device
    _broadcastDeviceStatus(deviceId, 'deviceOnline');

    // Deliver any pending messages
    _deliverPendingMessages(deviceId);

    print('[INFO] Device registered: $deviceName ($deviceId) code: $pairCode');
    return deviceId;
  }

  /// Handle ping to keep connection alive
  void _handlePing(String? deviceId, WebSocketChannel channel) {
    if (deviceId != null && _devices.containsKey(deviceId)) {
      _devices[deviceId]!.lastPing = DateTime.now();
    }
    _send(channel, {
      'type': 'pong',
      'senderId': 'server',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle WebRTC signaling messages (offer, answer, iceCandidate)
  void _handleSignaling(
      String? senderId, Map<String, dynamic> message) {
    _forwardToReceiver(senderId, message);
  }

  /// Handle pairing request - resolve pair code to device ID
  void _handlePairRequest(String? senderId, Map<String, dynamic> message) {
    if (senderId == null) return;

    final receiverId = message['receiverId'] as String?;
    if (receiverId == null) return;

    // Try to resolve pair code to device ID
    String? targetDeviceId = receiverId;
    if (_pairCodeToDeviceId.containsKey(receiverId)) {
      targetDeviceId = _pairCodeToDeviceId[receiverId];
    }

    if (targetDeviceId == null) {
      _sendDeviceOffline(senderId, receiverId);
      print('[PAIR] Pair request failed: code $receiverId not found');
      return;
    }

    _forwardToReceiver(senderId, message, resolvedReceiverId: targetDeviceId);
  }

  /// Handle pairing response
  void _handlePairResponse(String? senderId, Map<String, dynamic> message) {
    _forwardToReceiver(senderId, message);
  }

  /// Handle device disconnection
  void _handleDisconnect(String deviceId) {
    final device = _devices[deviceId];
    if (device != null) {
      // Broadcast BEFORE removing so _broadcastDeviceStatus can find the device
      _broadcastDeviceStatus(deviceId, 'deviceOffline', status: 'offline');
      _devices.remove(deviceId);
      _pairCodeToDeviceId.remove(device.pairCode);
      print('[INFO] Device disconnected: ${device.name} ($deviceId)');
    }
  }

  /// Send the current device list to a specific client
  void _sendDeviceList(WebSocketChannel channel) {
    final deviceList = _devices.values.map((d) => d.toJson()).toList();
    _send(channel, {
      'type': 'deviceList',
      'senderId': 'server',
      'data': {'devices': deviceList},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Broadcast device status change to all connected devices
  void _broadcastDeviceStatus(String deviceId, String statusType, {String status = 'online'}) {
    final device = _devices[deviceId];
    if (device == null) return;

    final message = {
      'type': statusType,
      'senderId': 'server',
      'data': device.toJson(status: status),
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final entry in _devices.entries) {
      if (entry.key != deviceId) {
        _send(entry.value.channel, message);
      }
    }
  }

  /// Notify sender that target device is offline
  void _sendDeviceOffline(String senderId, String targetId) {
    final sender = _devices[senderId];
    if (sender == null) return;

    _send(sender.channel, {
      'type': 'deviceOffline',
      'senderId': 'server',
      'data': {
        'id': targetId,
        'name': 'Unknown',
        'type': 'unknown',
        'status': 'offline',
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Store a message for later delivery (with size limit)
  void _storePendingMessage(
      String deviceId, Map<String, dynamic> message) {
    _pendingMessages.putIfAbsent(deviceId, () => []);
    final queue = _pendingMessages[deviceId]!;
    if (queue.length >= _maxPendingMessages) {
      queue.removeAt(0); // Drop oldest message
    }
    queue.add(message);
  }

  /// Deliver pending messages when a device comes online
  void _deliverPendingMessages(String deviceId) {
    final messages = _pendingMessages.remove(deviceId);
    if (messages == null) return;

    final device = _devices[deviceId];
    if (device == null) return;

    for (final message in messages) {
      _send(device.channel, message);
    }
    print('[INFO] Delivered ${messages.length} pending messages to $deviceId');
  }

  /// Send a message to a WebSocket channel
  void _send(WebSocketChannel channel, Map<String, dynamic> message) {
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      print('[ERROR] Failed to send message: $e');
    }
  }

  /// Send an error message to a channel
  void _sendError(WebSocketChannel channel, String error) {
    _send(channel, {
      'type': 'error',
      'senderId': 'server',
      'data': {'message': error},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

Future<void> main(List<String> args) async {
  final server = SignalingServer();
  final port = int.parse(args.isNotEmpty ? args[0] : '8080');

  final handler = webSocketHandler((WebSocketChannel channel, String? protocol) {
    server.onConnection(channel);
  });

  final serverInstance = await shelf_io.serve(
    const shelf.Pipeline().addHandler(handler),
    '0.0.0.0',
    port,
  );

  server.startCleanupTimer();

  print('One2All Signaling Server running on ws://${serverInstance.address.host}:${serverInstance.port}');
  print('Press Ctrl+C to stop.');

  // Graceful shutdown on SIGINT
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n[INFO] Shutting down...');
    server.dispose();
    await serverInstance.close(force: true);
    print('[INFO] Server stopped.');
  });
}
