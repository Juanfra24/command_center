import 'package:equatable/equatable.dart';

/// Represents a proxy slot from Webshare
/// A slot is a fixed container that can hold different IP addresses over time
class ProxySlot extends Equatable {
  final String id;
  final String? webshareId; // Reference to Webshare proxy ID
  final String slotName;
  final int slotNumber;
  final String? currentIpAddressId; // Reference to the current ProxyIpAddress
  final String username;
  final String password;
  final int port;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final int totalIpChanges; // How many times the IP has been changed
  final List<String> linkedCharacters; // Characters using this slot
  final bool isActive;

  const ProxySlot({
    required this.id,
    this.webshareId,
    required this.slotName,
    required this.slotNumber,
    this.currentIpAddressId,
    required this.username,
    required this.password,
    required this.port,
    required this.createdAt,
    required this.lastUpdated,
    required this.totalIpChanges,
    required this.linkedCharacters,
    required this.isActive,
  });

  factory ProxySlot.fromJson(Map<String, dynamic> json, {String? docId}) {
    if (json.isEmpty) return ProxySlot.empty();
    return ProxySlot(
      id: docId ?? json['id'] ?? '',
      webshareId: json['webshare_id'],
      slotName: json['slot_name'] ?? 'Slot',
      slotNumber: json['slot_number'] ?? 0,
      currentIpAddressId: json['current_ip_address_id'],
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      port: json['port'] ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      lastUpdated: _parseDateTime(json['last_updated']),
      totalIpChanges: json['total_ip_changes'] ?? 0,
      linkedCharacters: List<String>.from(json['linked_characters'] ?? []),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'webshare_id': webshareId,
        'slot_name': slotName,
        'slot_number': slotNumber,
        'current_ip_address_id': currentIpAddressId,
        'username': username,
        'password': password,
        'port': port,
        'created_at': createdAt.toIso8601String(),
        'last_updated': lastUpdated.toIso8601String(),
        'total_ip_changes': totalIpChanges,
        'linked_characters': linkedCharacters,
        'is_active': isActive,
      };

  factory ProxySlot.empty() {
    return ProxySlot(
      id: '',
      webshareId: null,
      slotName: 'Empty Slot',
      slotNumber: 0,
      currentIpAddressId: null,
      username: '',
      password: '',
      port: 0,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      totalIpChanges: 0,
      linkedCharacters: const [],
      isActive: false,
    );
  }

  ProxySlot copyWith({
    String? id,
    String? webshareId,
    String? slotName,
    int? slotNumber,
    String? currentIpAddressId,
    String? username,
    String? password,
    int? port,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? totalIpChanges,
    List<String>? linkedCharacters,
    bool? isActive,
  }) {
    return ProxySlot(
      id: id ?? this.id,
      webshareId: webshareId ?? this.webshareId,
      slotName: slotName ?? this.slotName,
      slotNumber: slotNumber ?? this.slotNumber,
      currentIpAddressId: currentIpAddressId ?? this.currentIpAddressId,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalIpChanges: totalIpChanges ?? this.totalIpChanges,
      linkedCharacters: linkedCharacters ?? this.linkedCharacters,
      isActive: isActive ?? this.isActive,
    );
  }

  String generateProxyUrl(String ipAddress) {
    return "$username:$password@$ipAddress:$port";
  }

  @override
  List<Object?> get props => [
        id,
        webshareId,
        slotName,
        slotNumber,
        currentIpAddressId,
        username,
        password,
        port,
        createdAt,
        lastUpdated,
        totalIpChanges,
        linkedCharacters,
        isActive,
      ];
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
