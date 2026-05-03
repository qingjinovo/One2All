import 'dart:convert';

enum MessageType { text, clipboard, file, system }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime(0);

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        content: json['content'] as String,
        type: MessageType.values.byName(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Message.fromJsonString(String jsonString) =>
      Message.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
