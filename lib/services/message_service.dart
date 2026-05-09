import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/device.dart';
import '../models/message.dart';
import 'signaling_service.dart';
import 'webrtc_service.dart';

/// Callback for new messages
typedef OnNewMessageCallback = void Function(Message message);

/// Callback for file transfer progress (0.0 to 1.0, bytesTransferred, totalBytes)
typedef OnFileProgressCallback = void Function(String messageId, double progress, int bytesTransferred, int totalBytes);

/// Callback for connection method changes
typedef OnConnectionMethodCallback = void Function(String peerId, ConnectionMethod method);

/// Manages message sending, receiving, and history
class MessageService {
  final WebRTCService _webRTCService;
  final SignalingService _signalingService;
  final String _deviceId;
  static const _uuid = Uuid();
  static const String _historyKey = 'message_history';
  static const int _chunkSize = 64 * 1024; // 64KB per chunk
  static const int _bufferHighWater = 1 * 1024 * 1024; // 1MB buffer threshold
  static const int _relayChunkSize = 32 * 1024; // 32KB per relay chunk (smaller for WebSocket)

  final List<Message> _messages = [];
  final Map<String, List<Message>> _conversationMessages = {};
  String? _fileStoragePath;

  // Chunked file transfer state (incoming)
  final Map<String, _IncomingFileTransfer> _incomingFileTransfers = {};

  // Transfer timing for speed calculation
  final Map<String, DateTime> _transferStartTime = {};

  // Connection method tracking per peer
  final Map<String, ConnectionMethod> _connectionMethods = {};

  // Listener list (supports multiple listeners)
  final List<OnNewMessageCallback> _onNewMessageListeners = [];
  final List<OnFileProgressCallback> _onFileProgressListeners = [];
  final List<OnConnectionMethodCallback> _onConnectionMethodListeners = [];

  List<Message> get messages => List.unmodifiable(_messages);

  /// Get connection method for a peer
  ConnectionMethod getConnectionMethod(String peerId) {
    if (_webRTCService.isConnectedToPeer(peerId)) return ConnectionMethod.p2p;
    return _connectionMethods[peerId] ?? ConnectionMethod.disconnected;
  }

  MessageService(this._webRTCService, this._signalingService, this._deviceId) {
    _webRTCService.addMessageReceivedListener(_onMessageReceived);
    _webRTCService.addBinaryMessageReceivedListener(_onBinaryMessageReceived);
    _webRTCService.addPeerConnectionChangedListener(_onPeerConnectionChanged);
    _signalingService.addRelayListener(_onRelayReceived);
    _initFileStorage();
  }

  void _onPeerConnectionChanged(String peerId, bool connected) {
    if (connected) {
      _setConnectionMethod(peerId, ConnectionMethod.p2p);
    }
    // Don't set disconnected here — let the relay fallback handle it
  }

  void _setConnectionMethod(String peerId, ConnectionMethod method) {
    final old = _connectionMethods[peerId];
    if (old != method) {
      _connectionMethods[peerId] = method;
      for (final listener in _onConnectionMethodListeners) {
        listener(peerId, method);
      }
    }
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

  void addConnectionMethodListener(OnConnectionMethodCallback callback) =>
      _onConnectionMethodListeners.add(callback);
  void removeConnectionMethodListener(OnConnectionMethodCallback callback) =>
      _onConnectionMethodListeners.remove(callback);

  /// Get messages for a specific conversation (peer)
  List<Message> getConversation(String peerId) {
    return List.unmodifiable(_conversationMessages[peerId] ?? []);
  }

  /// Send a text message to a peer (P2P first, relay fallback)
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

    // Try WebRTC P2P first
    bool sent = await _webRTCService.sendMessage(peerId, payload);

    // Fallback to relay if P2P fails
    if (!sent && _signalingService.isConnected) {
      debugPrint('[Message] P2P failed, trying relay for $peerId');
      _signalingService.sendRelayMessage(
        receiverId: peerId,
        data: {'type': 'message', 'message': message.toJson()},
      );
      sent = true;
      _setConnectionMethod(peerId, ConnectionMethod.relay);
    }

    final updatedMessage = message.copyWith(
      status: sent ? MessageStatus.sent : MessageStatus.failed,
    );
    _updateMessage(message.id, updatedMessage);
    await _saveHistory();

    if (!sent) {
      debugPrint('[Message] Failed to send to $peerId (both P2P and relay)');
      return false;
    }

    debugPrint('[Message] Sent to $peerId: $content');
    return true;
  }

  /// Send clipboard content to a peer (P2P first, relay fallback)
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

    // Try WebRTC P2P first
    bool sent = await _webRTCService.sendMessage(peerId, payload);

    // Fallback to relay
    if (!sent && _signalingService.isConnected) {
      debugPrint('[Message] P2P failed, relay clipboard to $peerId');
      _signalingService.sendRelayClipboard(
        receiverId: peerId,
        data: {'type': 'clipboard', 'message': message.toJson()},
      );
      sent = true;
      _setConnectionMethod(peerId, ConnectionMethod.relay);
    }

    if (!sent) {
      debugPrint('[Message] Failed to send clipboard to $peerId');
      return false;
    }

    _addMessage(message);
    await _saveHistory();

    debugPrint('[Message] Clipboard sent to $peerId');
    return true;
  }

  /// Send a file to a peer using chunked binary transfer (P2P first, relay fallback)
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
      final savedPath = await _saveFileToDisk(messageId, fileBytes, fileName: name);

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

      // Check if P2P is available
      final useP2P = _webRTCService.isConnectedToPeer(peerId);

      if (useP2P) {
        return await _sendFileP2P(peerId, messageId, name, mime, totalSize, fileBytes, message, onProgress);
      } else if (_signalingService.isConnected) {
        debugPrint('[Message] P2P unavailable, using relay for file to $peerId');
        _setConnectionMethod(peerId, ConnectionMethod.relay);
        return await _sendFileRelay(peerId, messageId, name, mime, totalSize, fileBytes, message, onProgress);
      } else {
        _updateMessage(messageId, message.copyWith(status: MessageStatus.failed));
        await _saveHistory();
        debugPrint('[Message] No connection available for file transfer to $peerId');
        return false;
      }
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

  /// Send file via WebRTC P2P data channel
  Future<bool> _sendFileP2P(
    String peerId, String messageId, String name, String mime,
    int totalSize, Uint8List fileBytes, Message message,
    OnFileProgressCallback? onProgress,
  ) async {
    // Send file_start control message
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
      return false;
    }

    // Send file in chunks with backpressure
    int offset = 0;
    while (offset < totalSize) {
      while (_webRTCService.getBufferedAmount(peerId) > _bufferHighWater) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final end = (offset + _chunkSize < totalSize) ? offset + _chunkSize : totalSize;
      final chunk = Uint8List.sublistView(fileBytes, offset, end);

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
        return false;
      }

      offset = end;
      final progress = offset / totalSize;
      if (onProgress != null) onProgress(messageId, progress, offset, totalSize);
      for (final listener in _onFileProgressListeners) {
        listener(messageId, progress, offset, totalSize);
      }
    }

    // Send file_end
    await _webRTCService.sendMessage(peerId, jsonEncode({
      'type': 'file_end',
      'messageId': messageId,
    }));

    _transferStartTime.remove(messageId);
    _updateMessage(messageId, message.copyWith(status: MessageStatus.sent));
    await _saveHistory();
    debugPrint('[Message] File "$name" sent via P2P to $peerId');
    return true;
  }

  /// Send file via WebSocket relay (base64 encoded chunks)
  Future<bool> _sendFileRelay(
    String peerId, String messageId, String name, String mime,
    int totalSize, Uint8List fileBytes, Message message,
    OnFileProgressCallback? onProgress,
  ) async {
    // Send relay file start
    _signalingService.sendRelayFileStart(
      receiverId: peerId,
      data: {
        'type': 'relayFileStart',
        'messageId': messageId,
        'fileName': name,
        'fileSize': totalSize,
        'mimeType': mime,
        'senderId': _deviceId,
        'receiverId': peerId,
      },
    );

    // Send file in base64-encoded chunks via relay
    int offset = 0;
    while (offset < totalSize) {
      final end = (offset + _relayChunkSize < totalSize) ? offset + _relayChunkSize : totalSize;
      final chunk = Uint8List.sublistView(fileBytes, offset, end);
      final base64Chunk = base64Encode(chunk);

      _signalingService.sendRelayFileChunk(
        receiverId: peerId,
        data: {
          'type': 'relayFileChunk',
          'messageId': messageId,
          'chunk': base64Chunk,
          'offset': offset,
        },
      );

      offset = end;
      final progress = offset / totalSize;
      if (onProgress != null) onProgress(messageId, progress, offset, totalSize);
      for (final listener in _onFileProgressListeners) {
        listener(messageId, progress, offset, totalSize);
      }

      // Small delay to avoid overwhelming the WebSocket
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Send relay file end
    _signalingService.sendRelayFileEnd(
      receiverId: peerId,
      data: {
        'type': 'relayFileEnd',
        'messageId': messageId,
      },
    );

    _transferStartTime.remove(messageId);
    _updateMessage(messageId, message.copyWith(status: MessageStatus.sent));
    await _saveHistory();
    debugPrint('[Message] File "$name" sent via relay to $peerId');
    return true;
  }

  /// Retry sending a failed file message
  Future<bool> retryFile(String peerId, Message message) async {
    if (message.status != MessageStatus.failed) return false;
    if (message.filePath == null || !await File(message.filePath!).exists()) {
      debugPrint('[Message] Cannot retry: file not found at ${message.filePath}');
      return false;
    }

    // Reset message status to sending
    _updateMessage(message.id, message.copyWith(status: MessageStatus.sending));
    await _saveHistory();

    // Re-send the file
    return sendFile(
      peerId,
      message.filePath!,
      fileName: message.fileName,
      mimeType: message.mimeType,
    );
  }

  /// Save file bytes to disk using original filename, return the path
  Future<String> _saveFileToDisk(String messageId, List<int> bytes, {String? fileName}) async {
    if (_fileStoragePath == null) {
      await _initFileStorage();
    }
    // Use original filename, avoid collisions by appending messageId prefix if needed
    final baseName = fileName ?? messageId;
    var path = '$_fileStoragePath${Platform.pathSeparator}$baseName';
    if (await File(path).exists()) {
      // File exists, prepend messageId prefix to avoid overwriting
      final ext = baseName.contains('.') ? '.${baseName.split('.').last}' : '';
      final nameWithoutExt = ext.isNotEmpty ? baseName.substring(0, baseName.length - ext.length) : baseName;
      path = '$_fileStoragePath${Platform.pathSeparator}${messageId.substring(0, 8)}_$nameWithoutExt$ext';
    }
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Load file data from disk for a message
  Future<Uint8List?> loadFileData(String messageId) async {
    try {
      if (_fileStoragePath == null) return null;
      // Find file by scanning storage — the message's filePath is preferred
      final storedPath = _messages.firstWhere((m) => m.id == messageId, orElse: () => Message(id: '', senderId: '', receiverId: '', content: '', type: MessageType.text, timestamp: DateTime(0))).filePath;
      if (storedPath != null && await File(storedPath).exists()) {
        return await File(storedPath).readAsBytes();
      }
      // Fallback: try messageId as filename (legacy)
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

    // Show file message immediately on receiver side
    final message = Message(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: fileName,
      type: MessageType.file,
      timestamp: DateTime.now(),
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      status: MessageStatus.sending,
    );
    _addMessage(message);
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
      final savedPath = await _saveFileToDisk(messageId, fileBytes, fileName: transfer.fileName);

      // Update existing message instead of creating new one
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final existing = _messages[index];
        final updated = existing.copyWith(
          filePath: savedPath,
          status: MessageStatus.sent,
        );
        _updateMessage(messageId, updated);
      } else {
        // Fallback: create new message if somehow not found
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
      }
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

  /// Handle incoming relay messages from the signaling server
  void _onRelayReceived(String senderId, String type, Map<String, dynamic> data) {
    try {
      debugPrint('[Message] Relay received from $senderId: $type');
      switch (type) {
        case 'relayMessage':
          final messageJson = data['message'] as Map<String, dynamic>?;
          if (messageJson != null) {
            final message = Message.fromJson(messageJson);
            _addMessage(message);
            _saveHistory();
          }
          break;

        case 'relayClipboard':
          final messageJson = data['message'] as Map<String, dynamic>?;
          if (messageJson != null) {
            final message = Message.fromJson(messageJson);
            _addMessage(message);
            _saveHistory();
          }
          break;

        case 'relayFileStart':
          _handleFileStart(data);
          break;

        case 'relayFileChunk':
          _handleRelayFileChunk(data);
          break;

        case 'relayFileEnd':
          _handleFileEnd(data);
          break;
      }
    } catch (e) {
      debugPrint('[Message] Error handling relay from $senderId: $e');
    }
  }

  /// Handle a relay file chunk (base64 encoded)
  void _handleRelayFileChunk(Map<String, dynamic> data) {
    try {
      final messageId = data['messageId'] as String;
      final chunkBase64 = data['chunk'] as String;
      final chunkBytes = base64Decode(chunkBase64);

      final transfer = _incomingFileTransfers[messageId];
      if (transfer == null) {
        debugPrint('[Message] Relay chunk for unknown transfer: $messageId');
        return;
      }

      transfer.bytesBuilder.add(chunkBytes);
      transfer.receivedBytes += chunkBytes.length;

      final progress = transfer.receivedBytes / transfer.totalSize;
      for (final listener in _onFileProgressListeners) {
        listener(messageId, progress, transfer.receivedBytes, transfer.totalSize);
      }
    } catch (e) {
      debugPrint('[Message] Error processing relay chunk: $e');
    }
  }

  void dispose() {
    _webRTCService.removeMessageReceivedListener(_onMessageReceived);
    _webRTCService.removeBinaryMessageReceivedListener(_onBinaryMessageReceived);
    _webRTCService.removePeerConnectionChangedListener(_onPeerConnectionChanged);
    _signalingService.removeRelayListener(_onRelayReceived);
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
