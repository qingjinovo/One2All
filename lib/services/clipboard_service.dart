import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/message.dart';
import 'message_service.dart';

/// Manages clipboard synchronization across devices
class ClipboardService {
  final MessageService _messageService;
  final String _deviceId;
  Timer? _pollTimer;
  String _lastClipboardContent = '';
  bool _isEnabled = false;
  bool _isSyncing = false;

  // List of peer IDs to sync clipboard with
  final Set<String> _syncPeers = {};

  static const Duration _pollInterval = Duration(seconds: 2);

  bool get isEnabled => _isEnabled;

  ClipboardService(this._messageService, this._deviceId) {
    _messageService.addNewMessageListener(_onNewMessage);
  }

  /// Enable clipboard sync
  void enable() {
    _isEnabled = true;
    _startPolling();
    debugPrint('[Clipboard] Sync enabled');
  }

  /// Disable clipboard sync
  void disable() {
    _isEnabled = false;
    _stopPolling();
    debugPrint('[Clipboard] Sync disabled');
  }

  /// Add a peer to sync clipboard with
  void addSyncPeer(String peerId) {
    _syncPeers.add(peerId);
    debugPrint('[Clipboard] Added sync peer: $peerId');
  }

  /// Remove a peer from clipboard sync
  void removeSyncPeer(String peerId) {
    _syncPeers.remove(peerId);
    debugPrint('[Clipboard] Removed sync peer: $peerId');
  }

  /// Manually sync clipboard content to all peers
  Future<void> syncNow() async {
    if (!_isEnabled || _isSyncing) return;
    await _checkAndSyncClipboard();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _checkAndSyncClipboard();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkAndSyncClipboard() async {
    if (_isSyncing || _syncPeers.isEmpty) return;

    try {
      _isSyncing = true;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final content = data?.text ?? '';

      if (content.isNotEmpty && content != _lastClipboardContent) {
        _lastClipboardContent = content;

        // Send to all sync peers
        for (final peerId in _syncPeers) {
          await _messageService.sendClipboard(peerId, content);
        }

        debugPrint('[Clipboard] Synced content to ${_syncPeers.length} peers');
      }
    } catch (e) {
      debugPrint('[Clipboard] Error checking clipboard: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void _onNewMessage(Message message) {
    if (message.type != MessageType.clipboard) return;
    if (message.senderId == _deviceId) return;

    // Received clipboard from peer, update local clipboard
    _updateLocalClipboard(message.content);
  }

  Future<void> _updateLocalClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      _lastClipboardContent = content;
      debugPrint('[Clipboard] Updated local clipboard from peer');
    } catch (e) {
      debugPrint('[Clipboard] Error setting clipboard: $e');
    }
  }

  void dispose() {
    disable();
    _messageService.removeNewMessageListener(_onNewMessage);
  }
}
