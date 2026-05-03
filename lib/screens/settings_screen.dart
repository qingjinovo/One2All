import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/clipboard_service.dart';
import '../services/message_service.dart';
import '../services/signaling_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _clipboardSync = false;
  bool _autoConnect = true;
  String _languageCode = 'zh';
  String _fileStoragePath = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text =
          prefs.getString('server_url') ?? 'ws://localhost:8080';
      _nameController.text = prefs.getString('device_name') ?? '';
      _clipboardSync = prefs.getBool('clipboard_sync') ?? false;
      _autoConnect = prefs.getBool('auto_connect') ?? true;
      _languageCode = prefs.getString('language_code') ?? 'zh';
      _fileStoragePath = prefs.getString('file_storage_path') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverController.text);
    await prefs.setString('device_name', _nameController.text);
    await prefs.setBool('clipboard_sync', _clipboardSync);
    await prefs.setBool('auto_connect', _autoConnect);
    await prefs.setString('language_code', _languageCode);
    if (_fileStoragePath.isNotEmpty) {
      await prefs.setString('file_storage_path', _fileStoragePath);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.settingsSaved)),
      );
    }
  }

  Future<void> _pickFileStoragePath() async {
    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder',
    );
    if (selectedPath == null) return;

    setState(() => _fileStoragePath = selectedPath);
    if (!mounted) return;
    final messageService = context.read<MessageService>();
    await messageService.setFileStoragePath(selectedPath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.settingsSaved)),
      );
    }
  }

  Future<void> _changeLanguage(String? langCode) async {
    if (langCode == null) return;
    setState(() => _languageCode = langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', langCode);
    if (mounted) {
      One2AllApp.setLocale(context, Locale(langCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: l10n.connection,
            icon: Icons.wifi,
            children: [
              TextField(
                controller: _serverController,
                decoration: InputDecoration(
                  labelText: l10n.signalingServerUrl,
                  hintText: 'ws://localhost:8080',
                  border: const OutlineInputBorder(),
                  helperText: l10n.signalingServerHelper,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.deviceName,
                  hintText: l10n.myComputer,
                  border: const OutlineInputBorder(),
                  helperText: l10n.deviceNameHelper,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.autoConnect),
                subtitle: Text(l10n.autoConnectSubtitle),
                value: _autoConnect,
                onChanged: (value) {
                  setState(() => _autoConnect = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: l10n.language,
            icon: Icons.language,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _languageCode,
                decoration: InputDecoration(
                  labelText: l10n.language,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'zh', child: Text('中文')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: _changeLanguage,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Sync',
            icon: Icons.sync,
            children: [
              SwitchListTile(
                title: Text(l10n.clipboardSync),
                subtitle: Text(l10n.clipboardSyncSubtitle),
                value: _clipboardSync,
                onChanged: (value) {
                  setState(() => _clipboardSync = value);
                  final clipboardService = context.read<ClipboardService>();
                  if (value) {
                    clipboardService.enable();
                  } else {
                    clipboardService.disable();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: l10n.fileStorageLocation,
            icon: Icons.folder,
            children: [
              Text(
                _fileStoragePath.isEmpty ? 'Default' : _fileStoragePath,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.fileStorageHelper,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.changeLocation),
                  onPressed: _pickFileStoragePath,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: l10n.about,
            icon: Icons.info,
            children: [
              ListTile(
                title: const Text('One2All'),
                subtitle: Text(l10n.version('1.3.0')),
              ),
              ListTile(
                title: Text(l10n.description),
                subtitle: Text(l10n.appDescription),
              ),
              ListTile(
                title: Text(l10n.connectionStatus),
                trailing: Consumer<SignalingService>(
                  builder: (context, service, _) {
                    return Chip(
                      label: Text(
                        service.isConnected ? l10n.connected : l10n.disconnected,
                      ),
                      backgroundColor: service.isConnected
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
