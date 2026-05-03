import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/device.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

import '../widgets/device_card.dart';
import '../widgets/connection_status.dart';
import 'chat_screen.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Device> _devices = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    final signaling = context.read<SignalingService>();
    final webRTC = context.read<WebRTCService>();

    signaling.addConnectionChangedListener(_onConnectionChanged);
    signaling.addDeviceListListener(_onDeviceList);
    signaling.addDeviceOnlineListener(_onDeviceOnline);
    signaling.addDeviceOfflineListener(_onDeviceOffline);
    signaling.addPairAcceptedListener(_onPairAccepted);
    webRTC.addPeerConnectionChangedListener(_onPeerConnectionChanged);
  }

  void _onConnectionChanged(bool connected) {
    if (mounted) setState(() => _isConnected = connected);
  }

  void _onDeviceList(List<Device> devices) {
    if (mounted) {
      setState(() {
        _devices.clear();
        // Default to offline - will be updated to online when WebRTC connects
        _devices.addAll(devices.map((d) => d.copyWith(status: DeviceStatus.offline)));
      });
    }
  }

  void _onDeviceOnline(Device device) {
    if (mounted) {
      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
        // Default to offline - will be updated to online when WebRTC connects
        _devices.add(device.copyWith(status: DeviceStatus.offline));
      });
    }
  }

  void _onDeviceOffline(Device device) {
    if (mounted) {
      setState(() {
        final index = _devices.indexWhere((d) => d.id == device.id);
        if (index >= 0) {
          _devices[index] = device.copyWith(status: DeviceStatus.offline);
        }
      });
    }
  }

  void _onPeerConnectionChanged(String peerId, bool connected) {
    if (mounted) {
      setState(() {
        final index = _devices.indexWhere((d) => d.id == peerId);
        if (index >= 0) {
          _devices[index] = _devices[index].copyWith(
            status: connected ? DeviceStatus.online : DeviceStatus.offline,
          );
        }
      });
    }
  }

  void _onPairAccepted(String peerId) {
    if (mounted) {
      setState(() {
        // Add device if not already in list
        if (!_devices.any((d) => d.id == peerId)) {
          _devices.add(Device(
            id: peerId,
            name: 'Paired Device',
            type: DeviceType.desktop,
            status: DeviceStatus.connecting,
          ));
        } else {
          final index = _devices.indexWhere((d) => d.id == peerId);
          if (index >= 0) {
            _devices[index] = _devices[index].copyWith(status: DeviceStatus.connecting);
          }
        }
      });
      // Initiate WebRTC connection to the paired peer
      final webRTC = context.read<WebRTCService>();
      webRTC.connectToPeer(peerId).then((success) {
        if (!success && mounted) {
          setState(() {
            final index = _devices.indexWhere((d) => d.id == peerId);
            if (index >= 0) {
              _devices[index] = _devices[index].copyWith(status: DeviceStatus.offline);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    final signaling = context.read<SignalingService>();
    final webRTC = context.read<WebRTCService>();

    signaling.removeConnectionChangedListener(_onConnectionChanged);
    signaling.removeDeviceListListener(_onDeviceList);
    signaling.removeDeviceOnlineListener(_onDeviceOnline);
    signaling.removeDeviceOfflineListener(_onDeviceOffline);
    signaling.removePairAcceptedListener(_onPairAccepted);
    webRTC.removePeerConnectionChangedListener(_onPeerConnectionChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          ConnectionStatus(isConnected: _isConnected),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToPairing(),
            tooltip: AppLocalizations.of(context)!.pairDevice,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(),
          ),
        ],
      ),
      body: _devices.isEmpty
          ? _buildEmptyState()
          : _buildDeviceList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToPairing(),
        icon: const Icon(Icons.add_link),
        label: Text(AppLocalizations.of(context)!.pairDevice),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noDevicesConnected,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.pairDeviceHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToPairing(),
            icon: const Icon(Icons.add_link),
            label: Text(AppLocalizations.of(context)!.pairYourFirstDevice),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return DeviceCard(
          device: device,
          onTap: () => _openChat(device),
          onConnect: () => _connectToDevice(device),
        );
      },
    );
  }

  void _navigateToPairing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PairingScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openChat(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(device: device),
      ),
    );
  }

  void _connectToDevice(Device device) {
    final webRTC = context.read<WebRTCService>();

    // Set connecting state
    setState(() {
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index >= 0) {
        _devices[index] = _devices[index].copyWith(status: DeviceStatus.connecting);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.connectingTo(device.name))),
    );

    webRTC.connectToPeer(device.id).then((success) {
      if (!success && mounted) {
        setState(() {
          final index = _devices.indexWhere((d) => d.id == device.id);
          if (index >= 0) {
            _devices[index] = _devices[index].copyWith(status: DeviceStatus.offline);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.connectionFailed)),
        );
      }
    });
  }
}
