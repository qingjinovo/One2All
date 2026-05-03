import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'One2All'**
  String get appTitle;

  /// Button to pair a device
  ///
  /// In en, this message translates to:
  /// **'Pair Device'**
  String get pairDevice;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No devices connected'**
  String get noDevicesConnected;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Pair a device to start messaging'**
  String get pairDeviceHint;

  /// Button in empty state
  ///
  /// In en, this message translates to:
  /// **'Pair Your First Device'**
  String get pairYourFirstDevice;

  /// Shown when connecting to a device
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}...'**
  String connectingTo(String deviceName);

  /// Connection status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Connection status
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Device status
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// Device status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// Connect button
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Connecting status
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// Connection error
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// Empty chat title
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// Empty chat subtitle
  ///
  /// In en, this message translates to:
  /// **'Send a message to {deviceName}'**
  String sendMessageHint(String deviceName);

  /// Message input hint
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeAMessage;

  /// File transfer stub
  ///
  /// In en, this message translates to:
  /// **'File transfer coming soon!'**
  String get fileTransferComingSoon;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get deviceInfo;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Sync Clipboard'**
  String get syncClipboard;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Accept button
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Decline button
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// Pairing page title
  ///
  /// In en, this message translates to:
  /// **'Connect a New Device'**
  String get connectNewDevice;

  /// Pairing page instructions
  ///
  /// In en, this message translates to:
  /// **'Enter the pairing code shown on the other device, or wait for an incoming request.'**
  String get pairingInstructions;

  /// Input label
  ///
  /// In en, this message translates to:
  /// **'Pairing Code'**
  String get pairingCode;

  /// Input hint
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enter6DigitCode;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Send Pair Request'**
  String get sendPairRequest;

  /// Divider text
  ///
  /// In en, this message translates to:
  /// **'Or wait for incoming request'**
  String get orWaitForRequest;

  /// Waiting text
  ///
  /// In en, this message translates to:
  /// **'Waiting for pairing request...'**
  String get waitingForPairing;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Start Listening'**
  String get startListening;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a 6-digit code'**
  String get pleaseEnter6DigitCode;

  /// Default device name
  ///
  /// In en, this message translates to:
  /// **'My Device'**
  String get myDevice;

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Pair request sent...'**
  String get pairRequestSent;

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Listening for pairing requests...'**
  String get listeningForPairing;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Pairing Request'**
  String get pairingRequest;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Device \"{senderName}\" wants to pair with you.'**
  String deviceWantsToPair(String senderName);

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Pairing successful!'**
  String get pairingSuccessful;

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Pairing request declined'**
  String get pairingRequestDeclined;

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Pairing request timed out'**
  String get pairingRequestTimedOut;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'My Pairing Code'**
  String get myPairingCode;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// SnackBar text
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// Input label
  ///
  /// In en, this message translates to:
  /// **'Signaling Server URL'**
  String get signalingServerUrl;

  /// Input helper
  ///
  /// In en, this message translates to:
  /// **'WebSocket URL of the signaling server'**
  String get signalingServerHelper;

  /// Input label
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// Input hint
  ///
  /// In en, this message translates to:
  /// **'My Computer'**
  String get myComputer;

  /// Input helper
  ///
  /// In en, this message translates to:
  /// **'Name shown to other devices'**
  String get deviceNameHelper;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Auto-connect'**
  String get autoConnect;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Automatically connect to known devices on startup'**
  String get autoConnectSubtitle;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Clipboard Sync'**
  String get clipboardSync;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Automatically sync clipboard across devices'**
  String get clipboardSyncSubtitle;

  /// Language selector label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// List item title
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// App description
  ///
  /// In en, this message translates to:
  /// **'Cross-platform device interconnection for file, message, and data sharing.'**
  String get appDescription;

  /// List item title
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// Clipboard message header
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboard;

  /// Date format
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String yesterday(String time);

  /// Device type
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Device type
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get tablet;

  /// Device type
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktop;

  /// Device type
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get linux;

  /// No description provided for @defaultDeviceNameWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows PC'**
  String get defaultDeviceNameWindows;

  /// No description provided for @defaultDeviceNameLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux PC'**
  String get defaultDeviceNameLinux;

  /// No description provided for @defaultDeviceNameMac.
  ///
  /// In en, this message translates to:
  /// **'Mac'**
  String get defaultDeviceNameMac;

  /// No description provided for @defaultDeviceNameAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android Device'**
  String get defaultDeviceNameAndroid;

  /// No description provided for @defaultDeviceNameIOS.
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get defaultDeviceNameIOS;

  /// No description provided for @defaultDeviceNameUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get defaultDeviceNameUnknown;

  /// Device info label
  ///
  /// In en, this message translates to:
  /// **'ID: {deviceId}'**
  String deviceIdLabel(String deviceId);

  /// Device info label
  ///
  /// In en, this message translates to:
  /// **'Type: {deviceType}'**
  String deviceTypeLabel(String deviceType);

  /// Device info label
  ///
  /// In en, this message translates to:
  /// **'Status: {deviceStatus}'**
  String deviceStatusLabel(String deviceStatus);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
