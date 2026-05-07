import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import 'webrtc_service.dart';

/// Callback for new messages
typedef OnNewMessageCallback = void Function(Message message);

/// Callback for file transfer progress (0.0 to 1.0, bytesTransferred, totalBytes)
typedef OnFileProgressCallback = void Function(String messageId, double progress, int bytesTransferred, int totalBytes);

/// Manages message sending, receiving, and history
class MessageService {
  final WebRTCService _webRTCService;
  final String _deviceId;
  static const _uuid = Uuid();
  static const String _historyKey = 'message_history';
  static const int _chunkSize = 64 * 1024; // 64KB per chunk

  final List<Message> _messages = [];
  final Map<String, List<Message>> _conversationMessages = {};
  String? _fileStoragePath;

  // Chunked file transfer state (incoming)
  final Map<String, _IncomingFileTransfer> _incomingFileTransfers = {};

  // Transfer timing for speed calculation
  final Map<String, DateTime> _transferStartTime = {};

  // Listener list (supports multiple listeners)
  final List<OnNewMessageCallback> _onNewMessageListeners = [];
  final List<OnFileProgressCallback> _onFileProgressListeners = [];

  List<Message> get messages => List.unmodifiable(_messages);

  MessageService(this._webRTCService, this._deviceId) {
    _webRTCService.addMessageReceivedListener(_onMessageReceived);
    _webRTCService.addBinaryMessageReceivedListener(_onBinaryMessageReceived);
    _initFileStorage();
  }

  Future<void> _initFileStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('file_storage_path');
      if (customPath != null && customPath.isNotEmpty) {
        _fileStoragePath = customPath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        _fileStoragePath = '${dir.path}${Platform.pathSeparator}One2All${Platform.pathSeparator}files';
      }
      final dir2 = Directory(_fileStoragePath!);
      if (!await dir2.exists()) {
        await dir2.create(recursive: true);
      }
      debugPrint('[Message] File storage: $_fileStoragePath');
    } catch (e) {
      debugPrint('[Message] Error init file storage: $e');
    }
  }

  // Add/Remove listener methods
  void addNewMessageListener(OnNewMessageCallback callback) =>
      _onNewMessageListeners.add(callback);
  void removeNewMessageListener(OnNewMessageCallback callback) =>
      _onNewMessageListeners.remove(callback);

  void addFileProgressListener(OnFileProgressCallback callback) =>
      _onFileProgressListeners.add(callback);
  void removeFileProgressListener(OnFileProgressCallback callback) =>
      _onFileProgressListeners.remove(callback);

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
      status: MessageStatus.sending,
    );

    _addMessage(message);

    final payload = jsonEncode({
      'type': 'message',
      'message': message.toJson(),
    });

    final sent = await _webRTCService.sendMessage(peerId, payload);

    final updatedMessage = message.copyWith(
      status: sent ? MessageStatus.sent : MessageStatus.failed,
    );
    _updateMessage(message.id, updatedMessage);
    await _saveHistory();

    if (!sent) {
      debugPrint('[Message] Failed to send to $peerId');
      return false;
    }

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

  /// Send a file to a peer using chunked binary transfer
  Future<bool> sendFile(String peerId, String filePath, {
    String? fileName,
    String? mimeType,
    OnFileProgressCallback? onProgress,
  }) async {
    final name = fileName ?? filePath.split(Platform.pathSeparator).last;
    final mime = mimeType ?? _guessMimeType(name);
    final messageId = _uuid.v4();

    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final totalSize = fileBytes.length;

      // Save file to local disk for persistence
      final savedPath = await _saveFileToDisk(messageId, fileBytes);

      // Create message with sending status
      final message = Message(
        id: messageId,
        senderId: _deviceId,
        receiverId: peerId,
        content: name,
        type: MessageType.file,
        timestamp: DateTime.now(),
        fileName: name,
        fileSize: totalSize,
        mimeType: mime,
        filePath: savedPath,
        status: MessageStatus.sending,
      );
      _addMessage(message);

      // Record transfer start time for speed calculation
      _transferStartTime[messageId] = DateTime.now();

      // Send file_start control message (metadata only, no file data)
      final startPayload = jsonEncode({
        'type': 'file_start',
        'messageId': messageId,
        'fileName': name,
        'fileSize': totalSize,
        'mimeType': mime,
        'senderId': _deviceId,
        'receiverId': peerId,
      });

      final started = await _webRTCService.sendMessage(peerId, startPayload);
      if (!started) {
        _updateMessage(messageId, message.copyWith(status: MessageStatus.failed));
        await _saveHistory();
        debugPrint('[Message] Failed to start file transfer to $peerId');
        return false;
      }

      // Send file in chunks
      int offset = 0;
      while (offset < totalSize) {
        final end = (offset + _chunkSize < totalSize) ? offset + _chunkSize : totalSize;
        final chunk = Uint8List.sublistView(fileBytes, offset, end);

        // Prepend 4-byte messageId length + messageId bytes for identification
        final msgIdBytes = utf8.encode(messageId);
        final header = ByteData(4)..setUint32(0, msgIdBytes.length);
        final binaryChunk = Uint8List(4 + msgIdBytes.length + chunk.length);
        binaryChunk.setAll(0, header.buffer.asUint8List());
        binaryChunk.setAll(4, msgIdBytes);
        binaryChunk.setAll(4 + msgIdBytes.length, chunk);

        final sent = await _webRTCService.sendBinary(peerId, binaryChunk);
        if (!sent) {
          _updateMessage(messageId, message.copyWith(status: MessageStatus.failed));
          await _saveHistory();
          debugPrint('[Message] Failed to send chunk at offset $offset');
          return false;
        }

        offset = end;
        final progress = offset / totalSize;
        if (onProgress != null) onProgress(messageId, progress, offset, totalSize);
        for (final listener in _onFileProgressListeners) {
          listener(messageId, progress, offset, totalSize);
        }
      }

      // Send file_end control message
      final endPayload = jsonEncode({
        'type': 'file_end',
        'messageId': messageId,
      });
      await _webRTCService.sendMessage(peerId, endPayload);

      // Clean up transfer timing
      _transferStartTime.remove(messageId);

      // Update message status to sent
      _updateMessage(messageId, message.copyWith(status: MessageStatus.sent));
      await _saveHistory();

      debugPrint('[Message] File "$name" ($totalSize bytes) sent to $peerId');
      return true;
    } catch (e) {
      debugPrint('[Message] Error sending file: $e');
      _transferStartTime.remove(messageId);
      _updateMessage(messageId, Message(
        id: messageId,
        senderId: _deviceId,
        receiverId: peerId,
        content: name,
        type: MessageType.file,
        timestamp: DateTime.now(),
        fileName: name,
        mimeType: mime,
        status: MessageStatus.failed,
      ));
      await _saveHistory();
      return false;
    }
  }

  /// Save file bytes to disk and return the path
  Future<String> _saveFileToDisk(String messageId, List<int> bytes) async {
    if (_fileStoragePath == null) {
      await _initFileStorage();
    }
    final path = '$_fileStoragePath${Platform.pathSeparator}$messageId';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Load file data from disk for a message
  Future<Uint8List?> loadFileData(String messageId) async {
    try {
      if (_fileStoragePath == null) return null;
      final path = '$_fileStoragePath${Platform.pathSeparator}$messageId';
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('[Message] Error loading file data: $e');
    }
    return null;
  }

  /// Save file bytes to a user-chosen location
  Future<String> saveFileToCustomLocation(Uint8List bytes, String fileName) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save File',
      fileName: fileName,
    );

    if (outputPath == null) throw Exception('User cancelled save');

    await File(outputPath).writeAsBytes(bytes);
    return outputPath;
  }

  /// Get the file storage directory path
  String? get fileStoragePath => _fileStoragePath;

  /// Update file storage path
  Future<void> setFileStoragePath(String path) async {
    _fileStoragePath = path;
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('file_storage_path', path);
  }

  /// Load custom file storage path from preferences
  Future<void> loadCustomStoragePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('file_storage_path');
      if (customPath != null && customPath.isNotEmpty) {
        _fileStoragePath = customPath;
        final dir = Directory(customPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('[Message] Error loading custom storage path: $e');
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

      if (type == 'message' || type == 'clipboard') {
        final messageJson = json['message'] as Map<String, dynamic>;
        final message = Message.fromJson(messageJson);
        _addMessage(message);
        _saveHistory();
        debugPrint('[Message] Received from $peerId: ${message.content}');
      } else if (type == 'file_start') {
        _handleFileStart(json);
      } else if (type == 'file_end') {
        _handleFileEnd(json);
      }
    } catch (e) {
      debugPrint('[Message] Error parsing message from $peerId: $e');
    }
  }

  void _onBinaryMessageReceived(String peerId, Uint8List data) {
    try {
      if (data.length < 4) return;

      // Extract messageId from binary header
      final msgIdLen = ByteData.sublistView(data, 0, 4).getUint32(0);
      if (data.length < 4 + msgIdLen) return;

      final messageId = utf8.decode(data.sublist(4, 4 + msgIdLen));
      final chunk = data.sublist(4 + msgIdLen);

      final transfer = _incomingFileTransfers[messageId];
      if (transfer == null) {
        debugPrint('[Message] Received chunk for unknown transfer: $messageId');
        return;
      }

      transfer.bytesBuilder.add(chunk);
      transfer.receivedBytes += chunk.length;

      // Notify progress
      final progress = transfer.receivedBytes / transfer.totalSize;
      for (final listener in _onFileProgressListeners) {
        listener(messageId, progress, transfer.receivedBytes, transfer.totalSize);
      }
    } catch (e) {
      debugPrint('[Message] Error processing binary chunk: $e');
    }
  }

  void _handleFileStart(Map<String, dynamic> json) {
    final messageId = json['messageId'] as String;
    final fileName = json['fileName'] as String;
    final fileSize = json['fileSize'] as int;
    final mimeType = json['mimeType'] as String;
    final senderId = json['senderId'] as String;
    final receiverId = json['receiverId'] as String;

    debugPrint('[Message] File transfer started: $fileName ($fileSize bytes)');

    _transferStartTime[messageId] = DateTime.now();
    _incomingFileTransfers[messageId] = _IncomingFileTransfer(
      messageId: messageId,
      fileName: fileName,
      totalSize: fileSize,
      mimeType: mimeType,
      senderId: senderId,
      receiverId: receiverId,
    );
  }

  Future<void> _handleFileEnd(Map<String, dynamic> json) async {
    final messageId = json['messageId'] as String;
    final transfer = _incomingFileTransfers.remove(messageId);
    _transferStartTime.remove(messageId);

    if (transfer == null) {
      debugPrint('[Message] file_end for unknown transfer: $messageId');
      return;
    }

    try {
      final fileBytes = transfer.bytesBuilder.toBytes();
      final savedPath = await _saveFileToDisk(messageId, fileBytes);

      final message = Message(
        id: messageId,
        senderId: transfer.senderId,
        receiverId: transfer.receiverId,
        content: transfer.fileName,
        type: MessageType.file,
        timestamp: DateTime.now(),
        fileName: transfer.fileName,
        fileSize: transfer.totalSize,
        mimeType: transfer.mimeType,
        filePath: savedPath,
      );

      _addMessage(message);
      await _saveHistory();
      debugPrint('[Message] File "${transfer.fileName}" received and saved');
    } catch (e) {
      debugPrint('[Message] Error saving received file: $e');
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

  void _updateMessage(String messageId, Message updatedMessage) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      _messages[index] = updatedMessage;
      final peerId = updatedMessage.senderId == _deviceId
          ? updatedMessage.receiverId
          : updatedMessage.senderId;
      final conv = _conversationMessages[peerId];
      if (conv != null) {
        final convIndex = conv.indexWhere((m) => m.id == messageId);
        if (convIndex >= 0) {
          conv[convIndex] = updatedMessage;
        }
      }
      for (final listener in _onNewMessageListeners) {
        listener(updatedMessage);
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
    _webRTCService.removeBinaryMessageReceivedListener(_onBinaryMessageReceived);
  }
}

/// Internal state for an incoming file transfer
class _IncomingFileTransfer {
  final String messageId;
  final String fileName;
  final int totalSize;
  final String mimeType;
  final String senderId;
  final String receiverId;
  final BytesBuilder bytesBuilder = BytesBuilder();
  int receivedBytes = 0;

  _IncomingFileTransfer({
    required this.messageId,
    required this.fileName,
    required this.totalSize,
    required this.mimeType,
    required this.senderId,
    required this.receiverId,
  });
}
