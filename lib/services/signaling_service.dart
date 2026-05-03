import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/device.dart';
import '../models/signal_message.dart';

/// Callback types for signaling events
typedef OnDeviceListCallback = void Function(List<Device> devices);
typedef OnDeviceStatusCallback = void Function(Device device);
typedef OnSignalCallback = void Function(SignalMessage message);
typedef OnPairRequestCallback = void Function(String senderId, String senderName);
typedef OnPairResponseCallback = void Function(String senderId, bool accepted);
typedef OnConnectionCallback = void Function(bool connected);
typedef OnPairCodeCallback = void Function(String pairCode);
typedef OnPairAcceptedCallback = void Function(String peerId);

/// Manages WebSocket connection to the signaling server
class SignalingService {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _connectTimeoutTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  DateTime _lastPongTime = DateTime.now();
  static const int _maxReconnectAttempts = 10;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _pongTimeout = Duration(seconds: 90);

  // Listener lists (supports multiple listeners)
  final List<OnDeviceListCallback> _onDeviceListListeners = [];
  final List<OnDeviceStatusCallback> _onDeviceOnlineListeners = [];
  final List<OnDeviceStatusCallback> _onDeviceOfflineListeners = [];
  final List<OnSignalCallback> _onSignalListeners = [];
  final List<OnPairRequestCallback> _onPairRequestListeners = [];
  final List<OnPairResponseCallback> _onPairResponseListeners = [];
  final List<OnConnectionCallback> _onConnectionChangedListeners = [];
  final List<OnPairCodeCallback> _onPairCodeAssignedListeners = [];
  final List<OnPairAcceptedCallback> _onPairAcceptedListeners = [];

  String? _deviceId;
  String? _serverUrl;
  String? _deviceName;
  String? _deviceType;
  String? _pairCode;

  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  String? get pairCode => _pairCode;

  // Add/Remove listener methods
  void addDeviceListListener(OnDeviceListCallback callback) =>
      _onDeviceListListeners.add(callback);
  void removeDeviceListListener(OnDeviceListCallback callback) =>
      _onDeviceListListeners.remove(callback);

  void addDeviceOnlineListener(OnDeviceStatusCallback callback) =>
      _onDeviceOnlineListeners.add(callback);
  void removeDeviceOnlineListener(OnDeviceStatusCallback callback) =>
      _onDeviceOnlineListeners.remove(callback);

  void addDeviceOfflineListener(OnDeviceStatusCallback callback) =>
      _onDeviceOfflineListeners.add(callback);
  void removeDeviceOfflineListener(OnDeviceStatusCallback callback) =>
      _onDeviceOfflineListeners.remove(callback);

  void addSignalListener(OnSignalCallback callback) =>
      _onSignalListeners.add(callback);
  void removeSignalListener(OnSignalCallback callback) =>
      _onSignalListeners.remove(callback);

  void addPairRequestListener(OnPairRequestCallback callback) =>
      _onPairRequestListeners.add(callback);
  void removePairRequestListener(OnPairRequestCallback callback) =>
      _onPairRequestListeners.remove(callback);

  void addPairResponseListener(OnPairResponseCallback callback) =>
      _onPairResponseListeners.add(callback);
  void removePairResponseListener(OnPairResponseCallback callback) =>
      _onPairResponseListeners.remove(callback);

  void addConnectionChangedListener(OnConnectionCallback callback) =>
      _onConnectionChangedListeners.add(callback);
  void removeConnectionChangedListener(OnConnectionCallback callback) =>
      _onConnectionChangedListeners.remove(callback);

  void addPairCodeAssignedListener(OnPairCodeCallback callback) {
    _onPairCodeAssignedListeners.add(callback);
    if (_pairCode != null) {
      callback(_pairCode!);
    }
  }
  void removePairCodeAssignedListener(OnPairCodeCallback callback) =>
      _onPairCodeAssignedListeners.remove(callback);

  void addPairAcceptedListener(OnPairAcceptedCallback callback) =>
      _onPairAcceptedListeners.add(callback);
  void removePairAcceptedListener(OnPairAcceptedCallback callback) =>
      _onPairAcceptedListeners.remove(callback);

  /// Notify listeners that a pairing was accepted (called by PairingScreen)
  void notifyPairAccepted(String peerId) {
    for (final listener in _onPairAcceptedListeners) {
      listener(peerId);
    }
  }

  /// Connect to the signaling server
  Future<void> connect({
    required String serverUrl,
    required String deviceId,
    required String deviceName,
    required String deviceType,
  }) async {
    _deviceId = deviceId;
    _serverUrl = serverUrl;
    _deviceName = deviceName;
    _deviceType = deviceType;
    _shouldReconnect = true;

    try {
      // Close old channel before creating new one
      _channel?.sink.close();
      _channel = null;

      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      // Listen for messages
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );

      // Register with the server
      final registerMsg = SignalMessage.register(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
      );
      _send(registerMsg);

      // Start connect timeout — if registerAck not received in time, reconnect
      _connectTimeoutTimer?.cancel();
      _connectTimeoutTimer = Timer(_connectTimeout, () {
        if (!_isConnected) {
          debugPrint('[Signaling] Connect timeout, no registerAck received');
          _channel?.sink.close();
        }
      });

      debugPrint('[Signaling] Connecting to $serverUrl...');
    } catch (e) {
      debugPrint('[Signaling] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Disconnect from the signaling server
  void disconnect() {
    _shouldReconnect = false;
    _isReconnecting = false;
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _connectTimeoutTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    for (final listener in _onConnectionChangedListeners) {
      listener(false);
    }
  }

  /// Send a signal message
  void sendSignal(SignalMessage message) {
    _send(message);
  }

  /// Send an offer to a peer
  void sendOffer({
    required String receiverId,
    required Map<String, dynamic> sdp,
  }) {
    if (_deviceId == null) return;
    _send(SignalMessage.offer(
      senderId: _deviceId!,
      receiverId: receiverId,
      sdp: sdp,
    ));
  }

  /// Send an answer to a peer
  void sendAnswer({
    required String receiverId,
    required Map<String, dynamic> sdp,
  }) {
    if (_deviceId == null) return;
    _send(SignalMessage.answer(
      senderId: _deviceId!,
      receiverId: receiverId,
      sdp: sdp,
    ));
  }

  /// Send an ICE candidate to a peer
  void sendIceCandidate({
    required String receiverId,
    required Map<String, dynamic> candidate,
  }) {
    if (_deviceId == null) return;
    _send(SignalMessage.iceCandidate(
      senderId: _deviceId!,
      receiverId: receiverId,
      candidate: candidate,
    ));
  }

  /// Send a pairing request
  void sendPairRequest({
    required String receiverId,
    required String senderName,
  }) {
    if (_deviceId == null) return;
    _send(SignalMessage.pairRequest(
      senderId: _deviceId!,
      receiverId: receiverId,
      senderName: senderName,
    ));
  }

  /// Send a pairing response
  void sendPairResponse({
    required String receiverId,
    required bool accepted,
  }) {
    if (_deviceId == null) return;
    _send(SignalMessage.pairResponse(
      senderId: _deviceId!,
      receiverId: receiverId,
      accepted: accepted,
    ));
  }

  /// Resolve a pairing code to a device ID
  void resolvePairCode(String pairCode) {
    if (_deviceId == null) return;
    _send(SignalMessage(
      type: SignalType.pairRequest,
      senderId: _deviceId,
      data: {'pairCode': pairCode},
    ));
  }

  void _send(SignalMessage message) {
    try {
      _channel?.sink.add(message.toJsonString());
    } catch (e) {
      debugPrint('[Signaling] Send error: $e');
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = SignalMessage.fromJson(json);

      switch (message.type) {
        case SignalType.registerAck:
          final deviceId = message.data?['deviceId'] as String?;
          final pairCode = message.data?['pairCode'] as String?;
          if (deviceId != null) {
            _deviceId = deviceId;
            debugPrint('[Signaling] Registered with ID: $deviceId');
          }
          if (pairCode != null) {
            _pairCode = pairCode;
            debugPrint('[Signaling] Pair code: $pairCode');
            for (final listener in _onPairCodeAssignedListeners) {
              listener(pairCode);
            }
          }
          // Connection confirmed by server
          _connectTimeoutTimer?.cancel();
          if (!_isConnected) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _lastPongTime = DateTime.now();
            for (final listener in _onConnectionChangedListeners) {
              listener(true);
            }
            _startPingTimer();
            debugPrint('[Signaling] Connection confirmed');
          }
          break;

        case SignalType.deviceList:
          final devicesJson =
              message.data?['devices'] as List<dynamic>? ?? [];
          final devices = devicesJson
              .map((d) => Device.fromJson(d as Map<String, dynamic>))
              .toList();
          for (final listener in _onDeviceListListeners) {
            listener(devices);
          }
          break;

        case SignalType.deviceOnline:
          if (message.data != null) {
            final device = Device.fromJson(message.data!);
            for (final listener in _onDeviceOnlineListeners) {
              listener(device);
            }
          }
          break;

        case SignalType.deviceOffline:
          if (message.data != null) {
            final device = Device.fromJson(message.data!);
            for (final listener in _onDeviceOfflineListeners) {
              listener(device);
            }
          }
          break;

        case SignalType.pairRequest:
          final senderId = message.senderId;
          final senderName = message.data?['senderName'] as String? ?? 'Unknown';
          if (senderId != null) {
            for (final listener in _onPairRequestListeners) {
              listener(senderId, senderName);
            }
          }
          break;

        case SignalType.pairResponse:
          final senderId = message.senderId;
          final accepted = message.data?['accepted'] as bool? ?? false;
          if (senderId != null) {
            for (final listener in _onPairResponseListeners) {
              listener(senderId, accepted);
            }
          }
          break;

        case SignalType.offer:
        case SignalType.answer:
        case SignalType.iceCandidate:
          for (final listener in _onSignalListeners) {
            listener(message);
          }
          break;

        case SignalType.pong:
          _lastPongTime = DateTime.now();
          break;

        default:
          debugPrint('[Signaling] Unhandled message type: ${message.type}');
      }
    } catch (e) {
      debugPrint('[Signaling] Message parse error: $e');
    }
  }

  void _onDisconnected() {
    if (!_isConnected && !_isReconnecting) return; // Already handled
    _isConnected = false;
    _connectTimeoutTimer?.cancel();
    _stopPingTimer();
    for (final listener in _onConnectionChangedListeners) {
      listener(false);
    }
    debugPrint('[Signaling] Disconnected');
    _scheduleReconnect();
  }

  void _onError(dynamic error) {
    debugPrint('[Signaling] Error: $error');
    if (!_isConnected && !_isReconnecting) return; // Already handled
    _isConnected = false;
    _connectTimeoutTimer?.cancel();
    _stopPingTimer();
    for (final listener in _onConnectionChangedListeners) {
      listener(false);
    }
    _scheduleReconnect();
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      // Check pong timeout — server may have silently died
      if (DateTime.now().difference(_lastPongTime) > _pongTimeout) {
        debugPrint('[Signaling] Pong timeout, server may be dead');
        _channel?.sink.close();
        return;
      }
      _send(SignalMessage(
        type: SignalType.ping,
        senderId: _deviceId,
      ));
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      _isReconnecting = false;
      return;
    }

    // Prevent duplicate scheduling
    if (_isReconnecting) return;
    _isReconnecting = true;

    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: _reconnectDelay.inSeconds * (_reconnectAttempts + 1),
    );
    _reconnectAttempts++;

    debugPrint(
        '[Signaling] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(delay, () {
      _isReconnecting = false;
      if (_serverUrl != null && _deviceId != null) {
        connect(
          serverUrl: _serverUrl!,
          deviceId: _deviceId!,
          deviceName: _deviceName ?? '',
          deviceType: _deviceType ?? 'desktop',
        );
      }
    });
  }

  void dispose() {
    disconnect();
  }
}
