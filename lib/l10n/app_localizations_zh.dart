// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'One2All';

  @override
  String get pairDevice => '配对设备';

  @override
  String get noDevicesConnected => '暂无连接的设备';

  @override
  String get pairDeviceHint => '配对一台设备以开始消息传递';

  @override
  String get pairYourFirstDevice => '配对您的第一台设备';

  @override
  String connectingTo(String deviceName) {
    return '正在连接到 $deviceName...';
  }

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get connect => '连接';

  @override
  String get connecting => '连接中';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get noMessagesYet => '暂无消息';

  @override
  String sendMessageHint(String deviceName) {
    return '向 $deviceName 发送消息';
  }

  @override
  String get typeAMessage => '输入消息...';

  @override
  String get fileTransferComingSoon => '文件传输功能即将推出！';

  @override
  String get deviceInfo => '设备信息';

  @override
  String get syncClipboard => '同步剪贴板';

  @override
  String get clearHistory => '清除历史';

  @override
  String get close => '关闭';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String get connectNewDevice => '连接新设备';

  @override
  String get pairingInstructions => '输入另一台设备上显示的配对码，或等待传入的配对请求。';

  @override
  String get pairingCode => '配对码';

  @override
  String get enter6DigitCode => '输入6位数字码';

  @override
  String get sendPairRequest => '发送配对请求';

  @override
  String get orWaitForRequest => '或等待传入的配对请求';

  @override
  String get waitingForPairing => '正在等待配对请求...';

  @override
  String get startListening => '开始监听';

  @override
  String get pleaseEnter6DigitCode => '请输入6位数字码';

  @override
  String get myDevice => '我的设备';

  @override
  String get pairRequestSent => '配对请求已发送...';

  @override
  String get listeningForPairing => '正在监听配对请求...';

  @override
  String get pairingRequest => '配对请求';

  @override
  String deviceWantsToPair(String senderName) {
    return '设备 \"$senderName\" 想要与您配对。';
  }

  @override
  String get pairingSuccessful => '配对成功！';

  @override
  String get pairingRequestDeclined => '配对请求已被拒绝';

  @override
  String get pairingRequestTimedOut => '配对请求已超时';

  @override
  String get myPairingCode => '我的配对码';

  @override
  String get settings => '设置';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get connection => '连接';

  @override
  String get signalingServerUrl => '信令服务器地址';

  @override
  String get signalingServerHelper => '信令服务器的 WebSocket 地址';

  @override
  String get deviceName => '设备名称';

  @override
  String get myComputer => '我的电脑';

  @override
  String get deviceNameHelper => '其他设备看到的名称';

  @override
  String get autoConnect => '自动连接';

  @override
  String get autoConnectSubtitle => '启动时自动连接到已知设备';

  @override
  String get clipboardSync => '剪贴板同步';

  @override
  String get clipboardSyncSubtitle => '自动在设备间同步剪贴板';

  @override
  String get language => '语言';

  @override
  String get about => '关于';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get description => '描述';

  @override
  String get appDescription => '跨平台设备互联，支持文件、消息和数据共享。';

  @override
  String get connectionStatus => '连接状态';

  @override
  String get clipboard => '剪贴板';

  @override
  String yesterday(String time) {
    return '昨天 $time';
  }

  @override
  String get phone => '手机';

  @override
  String get tablet => '平板';

  @override
  String get desktop => '桌面电脑';

  @override
  String get linux => 'Linux';

  @override
  String get defaultDeviceNameWindows => 'Windows 电脑';

  @override
  String get defaultDeviceNameLinux => 'Linux 电脑';

  @override
  String get defaultDeviceNameMac => 'Mac';

  @override
  String get defaultDeviceNameAndroid => 'Android 设备';

  @override
  String get defaultDeviceNameIOS => 'iPhone';

  @override
  String get defaultDeviceNameUnknown => '未知设备';

  @override
  String deviceIdLabel(String deviceId) {
    return 'ID: $deviceId';
  }

  @override
  String deviceTypeLabel(String deviceType) {
    return '类型: $deviceType';
  }

  @override
  String deviceStatusLabel(String deviceStatus) {
    return '状态: $deviceStatus';
  }
}
