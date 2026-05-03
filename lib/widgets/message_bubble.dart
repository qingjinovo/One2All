import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _getBackgroundColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
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
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(context, message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
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
            color: isMe
                ? Colors.white70
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.clipboard,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe
                  ? Colors.white70
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    if (isMe) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _getTextColor(BuildContext context) {
    if (isMe) {
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
