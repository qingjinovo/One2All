// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'One2All';

  @override
  String get pairDevice => 'Pair Device';

  @override
  String get noDevicesConnected => 'No devices connected';

  @override
  String get pairDeviceHint => 'Pair a device to start messaging';

  @override
  String get pairYourFirstDevice => 'Pair Your First Device';

  @override
  String connectingTo(String deviceName) {
    return 'Connecting to $deviceName...';
  }

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String sendingFile(String fileName) {
    return 'Sending $fileName...';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String sendMessageHint(String deviceName) {
    return 'Send a message to $deviceName';
  }

  @override
  String get typeAMessage => 'Type a message...';

  @override
  String get fileTransferComingSoon => 'File transfer coming soon!';

  @override
  String get deviceInfo => 'Device Info';

  @override
  String get syncClipboard => 'Sync Clipboard';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get close => 'Close';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get connectNewDevice => 'Connect a New Device';

  @override
  String get pairingInstructions =>
      'Enter the pairing code shown on the other device, or wait for an incoming request.';

  @override
  String get pairingCode => 'Pairing Code';

  @override
  String get enter6DigitCode => 'Enter 6-digit code';

  @override
  String get sendPairRequest => 'Send Pair Request';

  @override
  String get orWaitForRequest => 'Or wait for incoming request';

  @override
  String get waitingForPairing => 'Waiting for pairing request...';

  @override
  String get startListening => 'Start Listening';

  @override
  String get pleaseEnter6DigitCode => 'Please enter a 6-digit code';

  @override
  String get myDevice => 'My Device';

  @override
  String get pairRequestSent => 'Pair request sent...';

  @override
  String get listeningForPairing => 'Listening for pairing requests...';

  @override
  String get pairingRequest => 'Pairing Request';

  @override
  String deviceWantsToPair(String senderName) {
    return 'Device \"$senderName\" wants to pair with you.';
  }

  @override
  String get pairingSuccessful => 'Pairing successful!';

  @override
  String get pairingRequestDeclined => 'Pairing request declined';

  @override
  String get pairingRequestTimedOut => 'Pairing request timed out';

  @override
  String get myPairingCode => 'My Pairing Code';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get connection => 'Connection';

  @override
  String get signalingServerUrl => 'Signaling Server URL';

  @override
  String get signalingServerHelper => 'WebSocket URL of the signaling server';

  @override
  String get deviceName => 'Device Name';

  @override
  String get myComputer => 'My Computer';

  @override
  String get deviceNameHelper => 'Name shown to other devices';

  @override
  String get autoConnect => 'Auto-connect';

  @override
  String get autoConnectSubtitle =>
      'Automatically connect to known devices on startup';

  @override
  String get clipboardSync => 'Clipboard Sync';

  @override
  String get clipboardSyncSubtitle =>
      'Automatically sync clipboard across devices';

  @override
  String get language => 'Language';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get description => 'Description';

  @override
  String get appDescription =>
      'Cross-platform device interconnection for file, message, and data sharing.';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get clipboard => 'Clipboard';

  @override
  String yesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String get phone => 'Phone';

  @override
  String get tablet => 'Tablet';

  @override
  String get desktop => 'Desktop';

  @override
  String get linux => 'Linux';

  @override
  String get defaultDeviceNameWindows => 'Windows PC';

  @override
  String get defaultDeviceNameLinux => 'Linux PC';

  @override
  String get defaultDeviceNameMac => 'Mac';

  @override
  String get defaultDeviceNameAndroid => 'Android Device';

  @override
  String get defaultDeviceNameIOS => 'iPhone';

  @override
  String get defaultDeviceNameUnknown => 'Unknown Device';

  @override
  String deviceIdLabel(String deviceId) {
    return 'ID: $deviceId';
  }

  @override
  String deviceTypeLabel(String deviceType) {
    return 'Type: $deviceType';
  }

  @override
  String deviceStatusLabel(String deviceStatus) {
    return 'Status: $deviceStatus';
  }

  @override
  String get saveImage => 'Save Image';

  @override
  String fileSavedTo(String path) {
    return 'File saved to $path';
  }

  @override
  String get fileStorageLocation => 'File Storage Location';

  @override
  String get fileStorageHelper =>
      'Path where received files and images are saved';

  @override
  String get changeLocation => 'Change';

  @override
  String get selectFolder => 'Select Folder';
}
