import 'dart:convert';
import 'dart:io';

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

  /// Send a file to a peer
  Future<bool> sendFile(String peerId, String filePath, {
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final name = fileName ?? filePath.split(Platform.pathSeparator).last;
      final mime = mimeType ?? _guessMimeType(name);

      final message = Message(
        id: _uuid.v4(),
        senderId: _deviceId,
        receiverId: peerId,
        content: name,
        type: MessageType.file,
        timestamp: DateTime.now(),
        fileName: name,
        fileSize: bytes.length,
        mimeType: mime,
        fileData: base64Encode(bytes),
      );

      final payload = jsonEncode({
        'type': 'file',
        'message': message.toJson(),
      });

      final sent = await _webRTCService.sendMessage(peerId, payload);
      if (!sent) {
        debugPrint('[Message] Failed to send file to $peerId');
        return false;
      }

      _addMessage(message);
      await _saveHistory();

      debugPrint('[Message] File "$name" (${bytes.length} bytes) sent to $peerId');
      return true;
    } catch (e) {
      debugPrint('[Message] Error sending file: $e');
      return false;
    }
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
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

      if (type == 'message' || type == 'clipboard' || type == 'file') {
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
