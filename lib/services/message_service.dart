import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import 'webrtc_service.dart';

/// Callback for new messages
typedef OnNewMessageCallback = void Function(Message message);

/// Manages message sending, receiving, and history
class MessageService {
  final WebRTCService _webRTCService;
  final String _deviceId;
  static const _uuid = Uuid();
  static const String _historyKey = 'message_history';

  final List<Message> _messages = [];
  final Map<String, List<Message>> _conversationMessages = {};

  // Listener list (supports multiple listeners)
  final List<OnNewMessageCallback> _onNewMessageListeners = [];

  List<Message> get messages => List.unmodifiable(_messages);

  MessageService(this._webRTCService, this._deviceId) {
    _webRTCService.addMessageReceivedListener(_onMessageReceived);
  }

  // Add/Remove listener methods
  void addNewMessageListener(OnNewMessageCallback callback) =>
      _onNewMessageListeners.add(callback);
  void removeNewMessageListener(OnNewMessageCallback callback) =>
      _onNewMessageListeners.remove(callback);

  /// Get messages for a specific conversation (peer)
  List<Message> getConversation(String peerId) {
    return List.unmodifiable(_conversationMessages[peerId] ?? []);
  }

  /// Send a text message to a peer
  Future<bool> sendMessage(String peerId, String content) async {
    final message = Message(
      id: _uuid.v4(),
      senderId: _deviceId,
      receiverId: peerId,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    // Send via WebRTC data channel
    final payload = jsonEncode({
      'type': 'message',
      'message': message.toJson(),
    });

    final sent = await _webRTCService.sendMessage(peerId, payload);
    if (!sent) {
      debugPrint('[Message] Failed to send to $peerId');
      return false;
    }

    // Store locally
    _addMessage(message);
    await _saveHistory();

    debugPrint('[Message] Sent to $peerId: $content');
    return true;
  }

  /// Send clipboard content to a peer
  Future<bool> sendClipboard(String peerId, String content) async {
    final message = Message(
      id: _uuid.v4(),
      senderId: _deviceId,
      receiverId: peerId,
      content: content,
      type: MessageType.clipboard,
      timestamp: DateTime.now(),
    );

    final payload = jsonEncode({
      'type': 'clipboard',
      'message': message.toJson(),
    });

    final sent = await _webRTCService.sendMessage(peerId, payload);
    if (!sent) {
      debugPrint('[Message] Failed to send clipboard to $peerId');
      return false;
    }

    _addMessage(message);
    await _saveHistory();

    debugPrint('[Message] Clipboard sent to $peerId');
    return true;
  }

  /// Load message history from local storage
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      if (historyJson == null) return;

      final List<dynamic> historyList = jsonDecode(historyJson) as List<dynamic>;
      _messages.clear();
      _conversationMessages.clear();

      for (final item in historyList) {
        final message = Message.fromJson(item as Map<String, dynamic>);
        _addMessage(message, notify: false);
      }

      debugPrint('[Message] Loaded ${_messages.length} messages from history');
    } catch (e) {
      debugPrint('[Message] Error loading history: $e');
    }
  }

  /// Clear message history
  Future<void> clearHistory() async {
    _messages.clear();
    _conversationMessages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Clear history for a specific peer
  Future<void> clearConversation(String peerId) async {
    final conversation = _conversationMessages.remove(peerId);
    if (conversation != null) {
      _messages.removeWhere((m) =>
          m.senderId == peerId || m.receiverId == peerId);
      await _saveHistory();
    }
  }

  void _onMessageReceived(String peerId, String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'message' || type == 'clipboard') {
        final messageJson = json['message'] as Map<String, dynamic>;
        final message = Message.fromJson(messageJson);
        _addMessage(message);
        _saveHistory();
        debugPrint('[Message] Received from $peerId: ${message.content}');
      }
    } catch (e) {
      debugPrint('[Message] Error parsing message from $peerId: $e');
    }
  }

  void _addMessage(Message message, {bool notify = true}) {
    _messages.add(message);

    final peerId =
        message.senderId == _deviceId ? message.receiverId : message.senderId;
    _conversationMessages.putIfAbsent(peerId, () => []);
    _conversationMessages[peerId]!.add(message);

    if (notify) {
      for (final listener in _onNewMessageListeners) {
        listener(message);
      }
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_historyKey, historyJson);
    } catch (e) {
      debugPrint('[Message] Error saving history: $e');
    }
  }

  void dispose() {
    _webRTCService.removeMessageReceivedListener(_onMessageReceived);
  }
}
