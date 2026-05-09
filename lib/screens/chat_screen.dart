import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/webrtc_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Device device;

  const ChatScreen({super.key, required this.device});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final Map<String, _FileTransferState> _fileTransferState = {};
  bool _isConnected = false;
  ConnectionMethod _connectionMethod = ConnectionMethod.disconnected;

  late final WebRTCService _webRTC;
  late final MessageService _messageService;

  @override
  void initState() {
    super.initState();
    _webRTC = context.read<WebRTCService>();
    _messageService = context.read<MessageService>();

    _isConnected = _webRTC.isConnectedToPeer(widget.device.id);
    _connectionMethod = _messageService.getConnectionMethod(widget.device.id);

    _webRTC.addPeerConnectionChangedListener(_onPeerConnectionChanged);
    _messageService.addNewMessageListener(_onNewMessage);
    _messageService.addFileProgressListener(_onFileProgress);
    _messageService.addConnectionMethodListener(_onConnectionMethodChanged);

    _loadMessages();
  }

  void _onPeerConnectionChanged(String peerId, bool connected) {
    if (peerId == widget.device.id && mounted) {
      setState(() {
        _isConnected = connected;
        _connectionMethod = _messageService.getConnectionMethod(widget.device.id);
      });
    }
  }

  void _onConnectionMethodChanged(String peerId, ConnectionMethod method) {
    if (peerId == widget.device.id && mounted) {
      setState(() {
        _connectionMethod = method;
        _isConnected = method != ConnectionMethod.disconnected;
      });
    }
  }

  void _onFileProgress(String messageId, double progress, int bytesTransferred, int totalBytes) {
    if (mounted) {
      setState(() {
        final prev = _fileTransferState[messageId];
        final now = DateTime.now();
        // Calculate speed using a rolling window for smoother display
        double speed = 0;
        if (prev != null) {
          final elapsed = now.difference(prev.lastUpdateTime).inMilliseconds / 1000.0;
          if (elapsed > 0.1) {
            final bytesDelta = bytesTransferred - prev.lastBytesTransferred;
            speed = bytesDelta / elapsed;
          } else {
            speed = prev.speed;
          }
        } else {
          // First chunk — not enough data for speed yet
          speed = 0;
        }
        _fileTransferState[messageId] = _FileTransferState(
          progress: progress,
          bytesTransferred: bytesTransferred,
          totalBytes: totalBytes,
          speed: speed,
          lastUpdateTime: now,
          lastBytesTransferred: bytesTransferred,
        );
      });
    }
  }

  void _onNewMessage(Message message) {
    if ((message.senderId == widget.device.id ||
            message.receiverId == widget.device.id) &&
        mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          _messages[index] = message;
        } else {
          _messages.add(message);
        }
      });
      _scrollToBottom();
    }
  }

  void _loadMessages() {
    setState(() {
      _messages.addAll(_messageService.getConversation(widget.device.id));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name),
            Text(
              _getConnectionLabel(AppLocalizations.of(context)!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getConnectionColor(),
                  ),
            ),
          ],
        ),
        actions: [
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: _connect,
              tooltip: AppLocalizations.of(context)!.connect,
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyChat()
                : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noMessagesYet,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.sendMessageHint(widget.device.name),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId != widget.device.id;
        final state = _fileTransferState[message.id];
        // Clean up completed transfers
        if (state != null && message.status == MessageStatus.sent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _fileTransferState.remove(message.id));
          });
        }
        return MessageBubble(
          message: message,
          isMe: isMe,
          fileProgress: state?.progress,
          transferSpeed: state?.speed,
          bytesTransferred: state?.bytesTransferred,
          totalBytes: state?.totalBytes,
          onRetry: message.status == MessageStatus.failed
              ? () => _retryMessage(message)
              : null,
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _isConnected ? _attachFile : null,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.typeAMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: _isConnected,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isConnected ? _sendMessage : null,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _connect() {
    _webRTC.connectToPeer(widget.device.id);
  }

  String _getConnectionLabel(AppLocalizations l10n) {
    switch (_connectionMethod) {
      case ConnectionMethod.p2p:
        return l10n.connectionP2P;
      case ConnectionMethod.relay:
        return l10n.connectionRelay;
      case ConnectionMethod.disconnected:
        return l10n.disconnected;
    }
  }

  Color _getConnectionColor() {
    switch (_connectionMethod) {
      case ConnectionMethod.p2p:
        return Colors.green;
      case ConnectionMethod.relay:
        return Colors.blue;
      case ConnectionMethod.disconnected:
        return Colors.grey;
    }
  }

  void _retryMessage(Message message) {
    _messageService.retryFile(widget.device.id, message);
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageService.sendMessage(widget.device.id, content);
    _messageController.clear();
  }

  void _attachFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sendingFile(file.name))),
      );

      final sent = await _messageService.sendFile(
        widget.device.id,
        file.path!,
        fileName: file.name,
      );

      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.connectionFailed)),
        );
      }
    } catch (e) {
      debugPrint('[Chat] Error picking file: $e');
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(AppLocalizations.of(context)!.deviceInfo),
              onTap: () {
                Navigator.pop(context);
                _showDeviceInfo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(AppLocalizations.of(context)!.syncClipboard),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(AppLocalizations.of(context)!.clearHistory),
              onTap: () {
                Navigator.pop(context);
                _clearHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.deviceIdLabel(widget.device.id)),
            Text(AppLocalizations.of(context)!.deviceTypeLabel(widget.device.type.name)),
            Text(AppLocalizations.of(context)!.deviceStatusLabel(widget.device.status.name)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    _messageService.clearConversation(widget.device.id);
    setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _webRTC.removePeerConnectionChangedListener(_onPeerConnectionChanged);
    _messageService.removeNewMessageListener(_onNewMessage);
    _messageService.removeFileProgressListener(_onFileProgress);
    _messageService.removeConnectionMethodListener(_onConnectionMethodChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _FileTransferState {
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final double speed; // bytes per second
  final DateTime lastUpdateTime;
  final int lastBytesTransferred;

  _FileTransferState({
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speed,
    required this.lastUpdateTime,
    required this.lastBytesTransferred,
  });
}
