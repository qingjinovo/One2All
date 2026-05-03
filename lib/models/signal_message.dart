import 'dart:convert';

enum SignalType {
  // Device management
  register,
  registerAck,
  deviceList,
  deviceOnline,
  deviceOffline,

  // Pairing
  pairRequest,
  pairResponse,
  pairConfirm,

  // WebRTC signaling
  offer,
  answer,
  iceCandidate,

  // Ping/Pong
  ping,
  pong,
}

class SignalMessage {
  final SignalType type;
  final String? senderId;
  final String? receiverId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SignalMessage({
    required this.type,
    this.senderId,
    this.receiverId,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime(0);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (senderId != null) 'senderId': senderId,
        if (receiverId != null) 'receiverId': receiverId,
        if (data != null) 'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SignalMessage.fromJson(Map<String, dynamic> json) => SignalMessage(
        type: SignalType.values.byName(json['type'] as String),
        senderId: json['senderId'] as String?,
        receiverId: json['receiverId'] as String?,
        data: json['data'] as Map<String, dynamic>?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory SignalMessage.fromJsonString(String jsonString) =>
      SignalMessage.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Factory constructors for common messages
  factory SignalMessage.register({
    required String deviceId,
    required String deviceName,
    required String deviceType,
  }) =>
      SignalMessage(
        type: SignalType.register,
        senderId: deviceId,
        data: {
          'name': deviceName,
          'deviceType': deviceType,
        },
      );

  factory SignalMessage.pairRequest({
    required String senderId,
    required String receiverId,
    required String senderName,
  }) =>
      SignalMessage(
        type: SignalType.pairRequest,
        senderId: senderId,
        receiverId: receiverId,
        data: {'senderName': senderName},
      );

  factory SignalMessage.pairResponse({
    required String senderId,
    required String receiverId,
    required bool accepted,
  }) =>
      SignalMessage(
        type: SignalType.pairResponse,
        senderId: senderId,
        receiverId: receiverId,
        data: {'accepted': accepted},
      );

  factory SignalMessage.offer({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> sdp,
  }) =>
      SignalMessage(
        type: SignalType.offer,
        senderId: senderId,
        receiverId: receiverId,
        data: {'sdp': sdp},
      );

  factory SignalMessage.answer({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> sdp,
  }) =>
      SignalMessage(
        type: SignalType.answer,
        senderId: senderId,
        receiverId: receiverId,
        data: {'sdp': sdp},
      );

  factory SignalMessage.iceCandidate({
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> candidate,
  }) =>
      SignalMessage(
        type: SignalType.iceCandidate,
        senderId: senderId,
        receiverId: receiverId,
        data: {'candidate': candidate},
      );
}
