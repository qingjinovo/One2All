import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/device.dart';
import '../services/message_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final List<Device> _devices = [];
  bool _isConnected = false;
  bool _isRefreshing = false;
  String _deviceId = '';
  late AnimationController _refreshAnimController;

  @override
  void initState() {
    super.initState();
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadDeviceId();
    _loadKnownDevices();
    _setupCallbacks();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _deviceId = prefs.getString('device_id') ?? '');
  }

  Future<void> _loadKnownDevices() async {
    final signaling = context.read<SignalingService>();
    final devices = await signaling.loadKnownDevices();
    if (mounted && devices.isNotEmpty) {
      setState(() {
        _devices.clear();
        _devices.addAll(devices.where((d) => d.id != _deviceId).map(
          (d) => d.copyWith(status: DeviceStatus.offline),
        ));
      });
    }
  }

  void _setupCallbacks() {
    final signaling = context.read<SignalingService>();
    final webRTC = context.read<WebRTCService>();
    final messageService = context.read<MessageService>();

    signaling.addConnectionChangedListener(_onConnectionChanged);
    signaling.addDeviceListListener(_onDeviceList);
    signaling.addDeviceOnlineListener(_onDeviceOnline);
    signaling.addDeviceOfflineListener(_onDeviceOffline);
    signaling.addPairAcceptedListener(_onPairAccepted);
    webRTC.addPeerConnectionChangedListener(_onPeerConnectionChanged);
    messageService.addConnectionMethodListener(_onConnectionMethodChanged);
  }

  void _onConnectionMethodChanged(String peerId, ConnectionMethod method) {
    if (mounted) {
      setState(() {
        final index = _devices.indexWhere((d) => d.id == peerId);
        if (index >= 0) {
          _devices[index] = _devices[index].copyWith(
            connectionMethod: method,
            status: method == ConnectionMethod.disconnected
                ? DeviceStatus.offline
                : DeviceStatus.online,
          );
        }
      });
    }
  }

  void _onConnectionChanged(bool connected) {
    if (mounted) {
      setState(() {
        _isConnected = connected;
        if (connected) {
          _isRefreshing = false;
          _refreshAnimController.stop();
          _refreshAnimController.reset();
        }
      });
    }
  }

  void _onDeviceList(List<Device> devices) {
    if (mounted) {
      setState(() {
        _devices.clear();
        // Filter out own device and default to offline
        _devices.addAll(devices
            .where((d) => d.id != _deviceId)
            .map((d) => d.copyWith(status: DeviceStatus.offline)));
      });
    }
  }

  void _onDeviceOnline(Device device) {
    if (mounted) {
      if (device.id == _deviceId) return; // Skip own device
      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
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
          final messageService = context.read<MessageService>();
          _devices[index] = _devices[index].copyWith(
            status: connected ? DeviceStatus.online : DeviceStatus.offline,
            connectionMethod: messageService.getConnectionMethod(peerId),
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
    _refreshAnimController.dispose();
    final signaling = context.read<SignalingService>();
    final webRTC = context.read<WebRTCService>();
    final messageService = context.read<MessageService>();

    signaling.removeConnectionChangedListener(_onConnectionChanged);
    signaling.removeDeviceListListener(_onDeviceList);
    signaling.removeDeviceOnlineListener(_onDeviceOnline);
    signaling.removeDeviceOfflineListener(_onDeviceOffline);
    signaling.removePairAcceptedListener(_onPairAccepted);
    webRTC.removePeerConnectionChangedListener(_onPeerConnectionChanged);
    messageService.removeConnectionMethodListener(_onConnectionMethodChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: _toggleTheme,
            tooltip: AppLocalizations.of(context)!.toggleTheme,
          ),
          ConnectionStatus(isConnected: _isConnected),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToPairing(),
            tooltip: AppLocalizations.of(context)!.pairDevice,
          ),
          IconButton(
            icon: _isRefreshing
                ? RotationTransition(
                    turns: _refreshAnimController,
                    child: const Icon(Icons.refresh),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshConnection,
            tooltip: AppLocalizations.of(context)!.refreshConnection,
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

  void _toggleTheme() {
    final brightness = Theme.of(context).brightness;
    final newMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    One2AllApp.setThemeMode(context, newMode);
  }

  void _refreshConnection() {
    setState(() {
      _isRefreshing = true;
    });
    _refreshAnimController.repeat();
    final signaling = context.read<SignalingService>();
    signaling.reconnect();
    // Auto-stop animation after 10 seconds if not connected
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isRefreshing) {
        setState(() {
          _isRefreshing = false;
        });
        _refreshAnimController.stop();
        _refreshAnimController.reset();
      }
    });
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
    final signaling = context.read<SignalingService>();

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
        // P2P failed, try relay fallback
        if (signaling.isConnected) {
          debugPrint('[Home] P2P failed for ${device.id}, using relay');
          setState(() {
            final index = _devices.indexWhere((d) => d.id == device.id);
            if (index >= 0) {
              _devices[index] = _devices[index].copyWith(
                status: DeviceStatus.online,
                connectionMethod: ConnectionMethod.relay,
              );
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.connectionRelay)),
          );
        } else {
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
      }
    });
  }
}
