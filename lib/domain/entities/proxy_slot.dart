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
  final int? socksPort;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final int totalIpChanges;
  final bool isActive;
  final bool isDeleted;
  final DateTime? deletedAt;

  const ProxySlotEntity({
    this.id,
    this.webshareId,
    required this.slotName,
    required this.slotNumber,
    this.currentIpAddressId,
    required this.username,
    required this.password,
    required this.port,
    this.socksPort,
    required this.createdAt,
    required this.lastUpdated,
    required this.totalIpChanges,
    required this.isActive,
    this.isDeleted = false,
    this.deletedAt,
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
      socksPort: null,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      totalIpChanges: 0,
      isActive: false,
      isDeleted: false,
      deletedAt: null,
    );
  }

  static const _absent = Object();

  ProxySlotEntity copyWith({
    int? id,
    String? webshareId,
    String? slotName,
    int? slotNumber,
    Object? currentIpAddressId = _absent,
    String? username,
    String? password,
    int? port,
    Object? socksPort = _absent,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? totalIpChanges,
    bool? isActive,
    bool? isDeleted,
    Object? deletedAt = _absent,
  }) {
    return ProxySlotEntity(
      id: id ?? this.id,
      webshareId: webshareId ?? this.webshareId,
      slotName: slotName ?? this.slotName,
      slotNumber: slotNumber ?? this.slotNumber,
      currentIpAddressId: identical(currentIpAddressId, _absent)
          ? this.currentIpAddressId
          : currentIpAddressId as int?,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      socksPort:
          identical(socksPort, _absent) ? this.socksPort : socksPort as int?,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalIpChanges: totalIpChanges ?? this.totalIpChanges,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: identical(deletedAt, _absent)
          ? this.deletedAt
          : deletedAt as DateTime?,
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
        socksPort,
        createdAt,
        lastUpdated,
        totalIpChanges,
        isActive,
        isDeleted,
        deletedAt,
      ];
}
