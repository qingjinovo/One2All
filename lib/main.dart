import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'l10n/app_localizations.dart';

import 'screens/home_screen.dart';
import 'services/signaling_service.dart';
import 'services/webrtc_service.dart';
import 'services/message_service.dart';
import 'services/clipboard_service.dart';

const _uuid = Uuid();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load settings
  final prefs = await SharedPreferences.getInstance();
  final serverUrl = prefs.getString('server_url') ?? 'ws://localhost:8080';
  final deviceName = prefs.getString('device_name') ?? _getDefaultDeviceName();
  final deviceId = prefs.getString('device_id') ?? _uuid.v4();
  final clipboardSync = prefs.getBool('clipboard_sync') ?? false;
  final languageCode = prefs.getString('language_code') ?? 'zh';

  // Save device ID if not set
  if (!prefs.containsKey('device_id')) {
    await prefs.setString('device_id', deviceId);
  }

  // Initialize services
  final signalingService = SignalingService();
  final webRTCService = WebRTCService(signalingService);
  final messageService = MessageService(webRTCService, deviceId);
  final clipboardService = ClipboardService(messageService, deviceId);

  // Load custom storage path and message history
  await messageService.loadCustomStoragePath();
  await messageService.loadHistory();

  // Enable clipboard sync if configured
  if (clipboardSync) {
    clipboardService.enable();
  }

  // Connect to signaling server
  signalingService.connect(
    serverUrl: serverUrl,
    deviceId: deviceId,
    deviceName: deviceName,
    deviceType: _getDeviceType(),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: signalingService),
        Provider.value(value: webRTCService),
        Provider.value(value: messageService),
        Provider.value(value: clipboardService),
      ],
      child: One2AllApp(locale: Locale(languageCode)),
    ),
  );
}

String _getDefaultDeviceName() {
  if (Platform.isWindows) return 'Windows PC';
  if (Platform.isLinux) return 'Linux PC';
  if (Platform.isMacOS) return 'Mac';
  if (Platform.isAndroid) return 'Android Device';
  if (Platform.isIOS) return 'iPhone';
  return 'Unknown Device';
}

String _getDeviceType() {
  if (Platform.isWindows || Platform.isMacOS) return 'desktop';
  if (Platform.isLinux) return 'linux';
  if (Platform.isAndroid) return 'phone';
  if (Platform.isIOS) return 'phone';
  return 'desktop';
}

class One2AllApp extends StatefulWidget {
  final Locale locale;

  const One2AllApp({super.key, required this.locale});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_One2AllAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<One2AllApp> createState() => _One2AllAppState();
}

class _One2AllAppState extends State<One2AllApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One2All',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
