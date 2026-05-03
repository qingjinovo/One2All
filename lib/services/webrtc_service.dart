import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/signal_message.dart';
import 'signaling_service.dart';

/// Callback types for WebRTC events
typedef OnDataChannelCallback = void Function(String peerId, RTCDataChannel channel);
typedef OnMessageCallback = void Function(String peerId, String message);
typedef OnPeerConnectionCallback = void Function(String peerId, bool connected);

/// Manages WebRTC peer connections and data channels
class WebRTCService {
  final SignalingService _signalingService;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};

  // Listener lists (supports multiple listeners)
  final List<OnDataChannelCallback> _onDataChannelOpenListeners = [];
  final List<OnMessageCallback> _onMessageReceivedListeners = [];
  final List<OnPeerConnectionCallback> _onPeerConnectionChangedListeners = [];

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  static const Map<String, dynamic> _dcConstraints = {
    'mandatory': {},
    'optional': [],
  };

  WebRTCService(this._signalingService) {
    _signalingService.addSignalListener(_handleSignal);
  }

  // Add/Remove listener methods
  void addDataChannelOpenListener(OnDataChannelCallback callback) =>
      _onDataChannelOpenListeners.add(callback);
  void removeDataChannelOpenListener(OnDataChannelCallback callback) =>
      _onDataChannelOpenListeners.remove(callback);

  void addMessageReceivedListener(OnMessageCallback callback) =>
      _onMessageReceivedListeners.add(callback);
  void removeMessageReceivedListener(OnMessageCallback callback) =>
      _onMessageReceivedListeners.remove(callback);

  void addPeerConnectionChangedListener(OnPeerConnectionCallback callback) =>
      _onPeerConnectionChangedListeners.add(callback);
  void removePeerConnectionChangedListener(OnPeerConnectionCallback callback) =>
      _onPeerConnectionChangedListeners.remove(callback);

  /// Create a peer connection and data channel for a specific peer
  Future<bool> connectToPeer(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      debugPrint('[WebRTC] Already connected to $peerId');
      return true;
    }

    try {
      final pc = await createPeerConnection(_iceServers, _dcConstraints);
      _peerConnections[peerId] = pc;

      // Create data channel
      final dc = await pc.createDataChannel(
        'messaging',
        RTCDataChannelInit()..ordered = true,
      );
      _setupDataChannel(peerId, dc);

      // Set up ICE candidate handling
      pc.onIceCandidate = (candidate) {
        _signalingService.sendIceCandidate(
          receiverId: peerId,
          candidate: candidate.toMap(),
        );
      };

      pc.onIceConnectionState = (state) {
        debugPrint('[WebRTC] ICE state for $peerId: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          for (final listener in _onPeerConnectionChangedListeners) {
            listener(peerId, false);
          }
        }
      };

      pc.onDataChannel = (channel) {
        debugPrint('[WebRTC] Received data channel from $peerId');
        _setupDataChannel(peerId, channel);
      };

      // Create and send offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _signalingService.sendOffer(
        receiverId: peerId,
        sdp: offer.toMap(),
      );

      debugPrint('[WebRTC] Sent offer to $peerId');
      return true;
    } catch (e) {
      debugPrint('[WebRTC] Error connecting to $peerId: $e');
      await _closePeerConnection(peerId);
      return false;
    }
  }

  /// Send a message to a peer via data channel
  Future<bool> sendMessage(String peerId, String message) async {
    final dc = _dataChannels[peerId];
    if (dc == null) {
      debugPrint('[WebRTC] No data channel for $peerId');
      return false;
    }

    try {
      await dc.send(RTCDataChannelMessage(message));
      return true;
    } catch (e) {
      debugPrint('[WebRTC] Send error to $peerId: $e');
      return false;
    }
  }

  /// Check if connected to a peer (data channel is open)
  bool isConnectedToPeer(String peerId) {
    final dc = _dataChannels[peerId];
    return dc != null;
  }

  /// Get list of connected peer IDs
  List<String> get connectedPeers => _dataChannels.keys.toList();

  /// Handle incoming signaling messages
  void _handleSignal(SignalMessage message) async {
    final senderId = message.senderId;
    if (senderId == null) return;

    switch (message.type) {
      case SignalType.offer:
        await _handleOffer(senderId, message);
        break;
      case SignalType.answer:
        await _handleAnswer(senderId, message);
        break;
      case SignalType.iceCandidate:
        await _handleIceCandidate(senderId, message);
        break;
      default:
        break;
    }
  }

  Future<void> _handleOffer(String peerId, SignalMessage message) async {
    try {
      // Create peer connection if not exists
      if (!_peerConnections.containsKey(peerId)) {
        final pc = await createPeerConnection(_iceServers, _dcConstraints);
        _peerConnections[peerId] = pc;

        pc.onIceCandidate = (candidate) {
          _signalingService.sendIceCandidate(
            receiverId: peerId,
            candidate: candidate.toMap(),
          );
        };

        pc.onIceConnectionState = (state) {
          debugPrint('[WebRTC] ICE state for $peerId: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
              state ==
                  RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            for (final listener in _onPeerConnectionChangedListeners) {
              listener(peerId, false);
            }
          }
        };

        pc.onDataChannel = (channel) {
          debugPrint('[WebRTC] Received data channel from $peerId');
          _setupDataChannel(peerId, channel);
        };
      }

      final pc = _peerConnections[peerId]!;
      final sdp = message.data?['sdp'] as Map<String, dynamic>?;
      if (sdp == null) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
      );

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _signalingService.sendAnswer(
        receiverId: peerId,
        sdp: answer.toMap(),
      );

      debugPrint('[WebRTC] Sent answer to $peerId');
    } catch (e) {
      debugPrint('[WebRTC] Error handling offer from $peerId: $e');
    }
  }

  Future<void> _handleAnswer(String peerId, SignalMessage message) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc == null) return;

      final sdp = message.data?['sdp'] as Map<String, dynamic>?;
      if (sdp == null) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
      );

      debugPrint('[WebRTC] Set remote description from $peerId');
    } catch (e) {
      debugPrint('[WebRTC] Error handling answer from $peerId: $e');
    }
  }

  Future<void> _handleIceCandidate(
      String peerId, SignalMessage message) async {
    try {
      final pc = _peerConnections[peerId];
      if (pc == null) return;

      final candidateMap =
          message.data?['candidate'] as Map<String, dynamic>?;
      if (candidateMap == null) return;

      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );

      await pc.addCandidate(candidate);
      debugPrint('[WebRTC] Added ICE candidate from $peerId');
    } catch (e) {
      debugPrint('[WebRTC] Error handling ICE candidate from $peerId: $e');
    }
  }

  void _setupDataChannel(String peerId, RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannels[peerId] = channel;
        for (final listener in _onPeerConnectionChangedListeners) {
          listener(peerId, true);
        }
        for (final listener in _onDataChannelOpenListeners) {
          listener(peerId, channel);
        }
        debugPrint('[WebRTC] Data channel open with $peerId');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _dataChannels.remove(peerId);
        for (final listener in _onPeerConnectionChangedListeners) {
          listener(peerId, false);
        }
        debugPrint('[WebRTC] Data channel closed with $peerId');
      }
    };

    channel.onMessage = (message) {
      if (message.isBinary) {
        debugPrint('[WebRTC] Received binary message from $peerId');
        // Handle binary data (file chunks) later
      } else {
        for (final listener in _onMessageReceivedListeners) {
          listener(peerId, message.text);
        }
      }
    };
  }

  Future<void> _closePeerConnection(String peerId) async {
    final dc = _dataChannels.remove(peerId);
    await dc?.close();

    final pc = _peerConnections.remove(peerId);
    await pc?.close();

    for (final listener in _onPeerConnectionChangedListeners) {
      listener(peerId, false);
    }
  }

  /// Dispose all connections
  Future<void> dispose() async {
    for (final peerId in _peerConnections.keys.toList()) {
      await _closePeerConnection(peerId);
    }
    _peerConnections.clear();
    _dataChannels.clear();
    _signalingService.removeSignalListener(_handleSignal);
  }
}
