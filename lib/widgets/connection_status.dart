import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: isConnected ? l10n.online : l10n.offline,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
