import 'package:equatable/equatable.dart';

/// Domain entity for a proxy slot
/// This is a pure Dart class with no database dependencies
class ProxySlotEntity extends Equatable {
  final int? id;
  final String? webshareId;
  final String slotName;
  final int slotNumber;
  final int? currentIpAddressId;
  final String username;
  final String password;
  final int port;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final int totalIpChanges;
  final bool isActive;

  const ProxySlotEntity({
    this.id,
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
    required this.isActive,
  });

  factory ProxySlotEntity.empty() {
    return ProxySlotEntity(
      id: null,
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
      isActive: false,
    );
  }

  ProxySlotEntity copyWith({
    int? id,
    String? webshareId,
    String? slotName,
    int? slotNumber,
    int? currentIpAddressId,
    String? username,
    String? password,
    int? port,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? totalIpChanges,
    bool? isActive,
  }) {
    return ProxySlotEntity(
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
        isActive,
      ];
}
