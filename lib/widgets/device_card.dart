import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onConnect;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildDeviceIcon(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDeviceTypeLabel(l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(context, l10n),
              if (device.status != DeviceStatus.online && onConnect != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: onConnect,
                  tooltip: l10n.connect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (device.type) {
      case DeviceType.phone:
        icon = Icons.phone_android;
        color = Colors.blue;
        break;
      case DeviceType.tablet:
        icon = Icons.tablet_mac;
        color = Colors.purple;
        break;
      case DeviceType.desktop:
        icon = Icons.computer;
        color = Colors.green;
        break;
      case DeviceType.linux:
        icon = Icons.terminal;
        color = Colors.orange;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildStatusChip(BuildContext context, AppLocalizations l10n) {
    Color color;
    String label;

    switch (device.status) {
      case DeviceStatus.online:
        color = Colors.green;
        label = l10n.online;
        break;
      case DeviceStatus.offline:
        color = Colors.grey;
        label = l10n.offline;
        break;
      case DeviceStatus.connecting:
        color = Colors.orange;
        label = l10n.connecting;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDeviceTypeLabel(AppLocalizations l10n) {
    switch (device.type) {
      case DeviceType.phone:
        return l10n.phone;
      case DeviceType.tablet:
        return l10n.tablet;
      case DeviceType.desktop:
        return l10n.desktop;
      case DeviceType.linux:
        return l10n.linux;
    }
  }
}
