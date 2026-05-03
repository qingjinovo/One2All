import 'dart:convert';

enum DeviceType { phone, tablet, desktop, linux }

enum DeviceStatus { online, offline, connecting }

class Device {
  final String id;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.type,
    this.status = DeviceStatus.offline,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime(0);

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'status': status.name,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        type: DeviceType.values.byName(json['type'] as String),
        status: DeviceStatus.values.byName(json['status'] as String),
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Device.fromJsonString(String jsonString) =>
      Device.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device(id: $id, name: $name, type: $type, status: $status)';
}
