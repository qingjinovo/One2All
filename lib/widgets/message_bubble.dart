import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/message.dart';
import '../services/message_service.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final double? fileProgress;
  final double? transferSpeed; // bytes per second
  final int? bytesTransferred;
  final int? totalBytes;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.fileProgress,
    this.transferSpeed,
    this.bytesTransferred,
    this.totalBytes,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Uint8List? _imageBytes;
  bool _loadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadImageData();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _loadImageData();
    }
  }

  Future<void> _loadImageData() async {
    if (!widget.message.isImage || widget.message.type != MessageType.file) return;

    // If fileData is already in memory (just sent), use it
    if (widget.message.fileData != null) {
      setState(() => _imageBytes = base64Decode(widget.message.fileData!));
      return;
    }

    // Load from disk
    if (widget.message.filePath != null) {
      setState(() => _loadingImage = true);
      try {
        final service = context.read<MessageService>();
        final bytes = await service.loadFileData(widget.message.id);
        if (mounted && bytes != null) {
          setState(() {
            _imageBytes = bytes;
            _loadingImage = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _loadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: message.type == MessageType.file && message.isImage
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _getBackgroundColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: _buildContent(context),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(context, message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 11,
                      ),
                ),
                if (isMe && message.type != MessageType.file) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(context),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (widget.message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Theme.of(context).colorScheme.outline,
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done_all, size: 14, color: Theme.of(context).colorScheme.outline);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }

  Widget _buildContent(BuildContext context) {
    final message = widget.message;
    if (message.type == MessageType.file) {
      if (message.isImage) {
        return _buildImagePreview(context);
      }
      return _buildFileMessage(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.type == MessageType.clipboard)
          _buildClipboardHeader(context),
        Text(
          message.content,
          style: TextStyle(
            color: _getTextColor(context),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    if (_loadingImage) {
      return Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: widget.isMe ? Colors.white70 : Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_imageBytes == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.image, color: widget.isMe ? Colors.white70 : Colors.grey, size: 48),
            const SizedBox(height: 4),
            Text(
              widget.message.fileName ?? '',
              style: TextStyle(
                color: _getTextColor(context).withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFullImage(context, _imageBytes!),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.broken_image,
                      color: widget.isMe ? Colors.white70 : Colors.grey,
                      size: 48,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Text(
              widget.message.fileName ?? '',
              style: TextStyle(
                color: _getTextColor(context).withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    final message = widget.message;
    final progress = widget.fileProgress;
    final isTransferring = message.status == MessageStatus.sending && progress != null;
    final canOpen = message.filePath != null && !isTransferring;

    return GestureDetector(
      onTap: canOpen ? () => _openFile(context) : null,
      onSecondaryTap: canOpen ? () => _showFileContextMenu(context) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getFileIcon(),
            color: widget.isMe ? Colors.white70 : Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? message.content,
                  style: TextStyle(
                    color: _getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: canOpen ? TextDecoration.underline : null,
                    decorationColor: _getTextColor(context).withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: TextStyle(
                      color: _getTextColor(context).withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                if (isTransferring) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: (widget.isMe ? Colors.white : Colors.grey).withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isMe ? Colors.white : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildTransferInfo(progress),
                    style: TextStyle(
                      color: _getTextColor(context).withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ] else if (widget.isMe) ...[
                  const SizedBox(height: 2),
                  _buildStatusIcon(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTransferInfo(double progress) {
    final transferred = widget.bytesTransferred ?? 0;
    final total = widget.totalBytes ?? 0;
    final speed = widget.transferSpeed ?? 0;

    final transferredStr = _formatFileSize(transferred);
    final totalStr = _formatFileSize(total);
    final speedStr = speed > 0 ? _formatSpeed(speed) : '...';

    return '$transferredStr / $totalStr · $speedStr';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  void _openFile(BuildContext context) async {
    final filePath = widget.message.filePath;
    if (filePath == null) return;

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: ${result.message}')),
      );
    }
  }

  void _showFileContextMenu(BuildContext context) async {
    final filePath = widget.message.filePath;
    if (filePath == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width,
        offset.dy,
        offset.dx,
        offset.dy + renderBox.size.height,
      ),
      items: [
        PopupMenuItem(
          value: 'open',
          child: ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(AppLocalizations.of(context)!.openFile),
            dense: true,
          ),
        ),
        if (Platform.isWindows)
          PopupMenuItem(
            value: 'open_location',
            child: ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(AppLocalizations.of(context)!.openFileLocation),
              dense: true,
            ),
          ),
      ],
    );

    if (!context.mounted) return;
    if (value == 'open') {
      _openFile(context);
    } else if (value == 'open_location' && Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', filePath]);
    }
  }

  void _showFullImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(bytes),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save_alt, color: Colors.white, size: 28),
                    onPressed: () => _saveImage(context, bytes),
                    tooltip: AppLocalizations.of(context)!.saveImage,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveImage(BuildContext context, Uint8List bytes) async {
    try {
      final service = context.read<MessageService>();
      final savePath = await service.saveFileToCustomLocation(
        bytes,
        widget.message.fileName ?? 'image.png',
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fileSavedTo(savePath))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.connectionFailed)),
        );
      }
    }
  }

  IconData _getFileIcon() {
    final mime = widget.message.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.video_file;
    if (mime.startsWith('audio/')) return Icons.audio_file;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('word') || mime.contains('document')) return Icons.description;
    if (mime.contains('sheet') || mime.contains('excel')) return Icons.table_chart;
    if (mime.contains('zip') || mime.contains('archive')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildClipboardHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.content_paste,
            size: 14,
            color: widget.isMe
                ? Colors.white70
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.clipboard,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isMe
                  ? Colors.white70
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    if (widget.isMe) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _getTextColor(BuildContext context) {
    if (widget.isMe) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  String _formatTime(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDay == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return l10n.yesterday(DateFormat('HH:mm').format(timestamp));
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}
