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
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? fileData; // base64 encoded file data

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    DateTime? timestamp,
    this.isRead = false,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.fileData,
  }) : timestamp = timestamp ?? DateTime(0);

  bool get isImage => mimeType?.startsWith('image/') ?? false;

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? fileData,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileData: fileData ?? this.fileData,
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
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileData != null) 'fileData': fileData,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        content: json['content'] as String,
        type: MessageType.values.byName(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
        fileName: json['fileName'] as String?,
        fileSize: json['fileSize'] as int?,
        mimeType: json['mimeType'] as String?,
        fileData: json['fileData'] as String?,
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
