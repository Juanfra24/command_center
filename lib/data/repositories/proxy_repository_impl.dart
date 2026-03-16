import 'package:drift/drift.dart';

import '../../domain/entities/proxy_ip_address.dart';
import '../../domain/entities/proxy_slot.dart';
import '../../domain/repositories/proxy_repository.dart';
import '../database/app_database.dart';

/// Drift implementation of the ProxyRepository
class ProxyRepositoryImpl implements ProxyRepository {
  final AppDatabase _db;

  ProxyRepositoryImpl(this._db);

  // ============ Proxy Slot Operations ============

  @override
  Future<List<ProxySlotEntity>> getAllSlots() async {
    final query = _db.select(_db.proxySlotsTable)
      ..where((tbl) => tbl.isDeleted.equals(false));
    final results = await query.get();
    return results.map(_mapProxySlotRow).toList();
  }

  @override
  Future<List<ProxySlotEntity>> getAllSlotsIncludingDeleted() async {
    final results = await _db.select(_db.proxySlotsTable).get();
    return results.map(_mapProxySlotRow).toList();
  }

  @override
  Future<ProxySlotEntity?> getSlotById(int id) async {
    final query = _db.select(_db.proxySlotsTable)
      ..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _mapProxySlotRow(result) : null;
  }

  @override
  Future<ProxySlotEntity?> getSlotByWebshareId(String webshareId) async {
    final query = _db.select(_db.proxySlotsTable)
      ..where((tbl) => tbl.webshareId.equals(webshareId));
    final result = await query.getSingleOrNull();
    return result != null ? _mapProxySlotRow(result) : null;
  }

  @override
  Future<ProxySlotEntity?> getSlotByNumber(int slotNumber) async {
    final query = _db.select(_db.proxySlotsTable)
      ..where((tbl) => tbl.slotNumber.equals(slotNumber));
    final result = await query.getSingleOrNull();
    return result != null ? _mapProxySlotRow(result) : null;
  }

  @override
  Future<int> insertSlot(ProxySlotEntity slot) async {
    return await _db.into(_db.proxySlotsTable).insert(
          ProxySlotsTableCompanion.insert(
            webshareId: slot.webshareId ?? '',
            slotName: Value(slot.slotName),
            slotNumber: slot.slotNumber,
            currentIpAddressId: Value(slot.currentIpAddressId),
            username: slot.username,
            password: slot.password,
            port: Value(slot.port),
            createdAt: Value(slot.createdAt),
            lastUpdated: Value(slot.lastUpdated),
            totalIpChanges: Value(slot.totalIpChanges),
            isActive: Value(slot.isActive),
            isDeleted: Value(slot.isDeleted),
            deletedAt: Value(slot.deletedAt),
          ),
        );
  }

  @override
  Future<void> updateSlot(ProxySlotEntity slot) async {
    if (slot.id == null) {
      throw ArgumentError('Cannot update slot without an id');
    }
    await (_db.update(_db.proxySlotsTable)
          ..where((tbl) => tbl.id.equals(slot.id!)))
        .write(
      ProxySlotsTableCompanion(
        webshareId: Value(slot.webshareId ?? ''),
        slotName: Value(slot.slotName),
        slotNumber: Value(slot.slotNumber),
        currentIpAddressId: Value(slot.currentIpAddressId),
        username: Value(slot.username),
        password: Value(slot.password),
        port: Value(slot.port),
        lastUpdated: Value(DateTime.now()),
        totalIpChanges: Value(slot.totalIpChanges),
        isActive: Value(slot.isActive),
        isDeleted: Value(slot.isDeleted),
        deletedAt: Value(slot.deletedAt),
      ),
    );
  }

  @override
  Future<void> softDeleteSlot(int id) async {
    await (_db.update(_db.proxySlotsTable)..where((tbl) => tbl.id.equals(id)))
        .write(
      ProxySlotsTableCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.now()),
        isActive: const Value(false),
      ),
    );
  }

  @override
  Future<void> softDeleteAllSlots() async {
    await (_db.update(_db.proxySlotsTable)
          ..where((t) => t.isDeleted.equals(false)))
        .write(const ProxySlotsTableCompanion(isDeleted: Value(true)));
  }

  @override
  Future<void> recoverSlot(int id) async {
    await (_db.update(_db.proxySlotsTable)..where((tbl) => tbl.id.equals(id)))
        .write(
      const ProxySlotsTableCompanion(
        isDeleted: Value(false),
        deletedAt: Value(null),
      ),
    );
  }

  @override
  Future<void> deleteSlot(int id) async {
    // First delete related IP addresses
    await (_db.delete(_db.proxyIpAddressesTable)
          ..where((tbl) => tbl.slotId.equals(id)))
        .go();
    // Then delete the slot
    await (_db.delete(_db.proxySlotsTable)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  @override
  Stream<List<ProxySlotEntity>> watchAllSlots() {
    final query = _db.select(_db.proxySlotsTable)
      ..where((tbl) => tbl.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.slotNumber)]);
    return query.watch().map((rows) => rows.map(_mapProxySlotRow).toList());
  }

  @override
  Future<int> upsertSlot(ProxySlotEntity slot) async {
    // Check if slot exists by webshareId
    if (slot.webshareId != null) {
      final existing = await getSlotByWebshareId(slot.webshareId!);

      if (existing != null) {
        // Update existing slot
        final updated = slot.copyWith(id: existing.id);
        await updateSlot(updated);
        return existing.id!;
      }
    }

    // Insert new slot
    return await insertSlot(slot);
  }

  // ============ IP Address Operations ============

  @override
  Future<List<ProxyIpAddressEntity>> getAllIpAddresses() async {
    final results = await _db.select(_db.proxyIpAddressesTable).get();
    return results.map(_mapIpAddressRow).toList();
  }

  @override
  Future<List<ProxyIpAddressEntity>> getIpAddressesForSlot(int slotId) async {
    final query = _db.select(_db.proxyIpAddressesTable)
      ..where((tbl) => tbl.slotId.equals(slotId))
      ..orderBy([(t) => OrderingTerm.desc(t.assignedAt)]);
    final results = await query.get();
    return results.map(_mapIpAddressRow).toList();
  }

  @override
  Future<ProxyIpAddressEntity?> getActiveIpForSlot(int slotId) async {
    final query = _db.select(_db.proxyIpAddressesTable)
      ..where((tbl) => tbl.slotId.equals(slotId) & tbl.isActive.equals(true));
    final result = await query.getSingleOrNull();
    return result != null ? _mapIpAddressRow(result) : null;
  }

  @override
  Future<int> insertIpAddress(ProxyIpAddressEntity ip) async {
    return await _db.into(_db.proxyIpAddressesTable).insert(
          ProxyIpAddressesTableCompanion.insert(
            ipAddress: ip.ipAddress,
            hostname: Value(ip.hostname),
            slotId: ip.slotId,
            isActive: Value(ip.isActive),
            countryCode: Value(ip.countryCode),
            cityName: Value(ip.cityName),
            ipTimezone: Value(ip.ipTimezone),
            highCountryConfidence: Value(ip.highCountryConfidence),
            asnName: Value(ip.asnName),
            asnNumber: Value(ip.asnNumber),
            ipScore: Value(ip.ipScore),
            scoreLevel: Value(ip.scoreLevel.name),
            isVpn: Value(ip.isVpn),
            isProxy: Value(ip.isProxy),
            isDatacenter: Value(ip.isDatacenter),
            isTor: Value(ip.isTor),
            isCrawler: Value(ip.isCrawler),
            connectionType: Value(ip.connectionType),
            isp: Value(ip.isp),
            organization: Value(ip.organization),
            region: Value(ip.region),
            recentAbuse: Value(ip.recentAbuse),
            fraudScore: Value(ip.fraudScore),
            assignedAt: Value(ip.assignedAt),
            removedAt: Value(ip.removedAt),
            lastVerification: Value(ip.lastVerification),
            lastScoreCheck: Value(ip.lastScoreCheck),
            totalDaysUsed: Value(ip.totalDaysUsed),
            timesAssigned: Value(ip.timesAssigned),
          ),
        );
  }

  @override
  Future<void> updateIpAddress(ProxyIpAddressEntity ip) async {
    if (ip.id == null) {
      throw ArgumentError('Cannot update IP address without an id');
    }
    await (_db.update(_db.proxyIpAddressesTable)
          ..where((tbl) => tbl.id.equals(ip.id!)))
        .write(
      ProxyIpAddressesTableCompanion(
        ipAddress: Value(ip.ipAddress),
        hostname: Value(ip.hostname),
        slotId: Value(ip.slotId),
        isActive: Value(ip.isActive),
        countryCode: Value(ip.countryCode),
        cityName: Value(ip.cityName),
        ipTimezone: Value(ip.ipTimezone),
        highCountryConfidence: Value(ip.highCountryConfidence),
        asnName: Value(ip.asnName),
        asnNumber: Value(ip.asnNumber),
        ipScore: Value(ip.ipScore),
        scoreLevel: Value(ip.scoreLevel.name),
        isVpn: Value(ip.isVpn),
        isProxy: Value(ip.isProxy),
        isDatacenter: Value(ip.isDatacenter),
        isTor: Value(ip.isTor),
        isCrawler: Value(ip.isCrawler),
        connectionType: Value(ip.connectionType),
        isp: Value(ip.isp),
        organization: Value(ip.organization),
        region: Value(ip.region),
        recentAbuse: Value(ip.recentAbuse),
        fraudScore: Value(ip.fraudScore),
        removedAt: Value(ip.removedAt),
        lastVerification: Value(ip.lastVerification),
        lastScoreCheck: Value(ip.lastScoreCheck),
        totalDaysUsed: Value(ip.totalDaysUsed),
        timesAssigned: Value(ip.timesAssigned),
      ),
    );
  }

  @override
  Future<void> deactivateIp(int ipId) async {
    await (_db.update(_db.proxyIpAddressesTable)
          ..where((tbl) => tbl.id.equals(ipId)))
        .write(
      ProxyIpAddressesTableCompanion(
        isActive: const Value(false),
        removedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<ProxyIpAddressEntity?> getIpAddressById(int id) async {
    final query = _db.select(_db.proxyIpAddressesTable)
      ..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _mapIpAddressRow(result) : null;
  }

  @override
  Future<void> deleteIpAddress(int id) async {
    await (_db.delete(_db.proxyIpAddressesTable)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  @override
  Stream<List<ProxyIpAddressEntity>> watchIpAddressesForSlot(int slotId) {
    final query = _db.select(_db.proxyIpAddressesTable)
      ..where((tbl) => tbl.slotId.equals(slotId))
      ..orderBy([(t) => OrderingTerm.desc(t.assignedAt)]);
    return query.watch().map((rows) => rows.map(_mapIpAddressRow).toList());
  }

  // ============ Mapping Helpers ============

  ProxySlotEntity _mapProxySlotRow(ProxySlotsTableData row) {
    return ProxySlotEntity(
      id: row.id,
      webshareId: row.webshareId,
      slotName: row.slotName,
      slotNumber: row.slotNumber,
      currentIpAddressId: row.currentIpAddressId,
      username: row.username,
      password: row.password,
      port: row.port,
      createdAt: row.createdAt,
      lastUpdated: row.lastUpdated,
      totalIpChanges: row.totalIpChanges,
      isActive: row.isActive,
      isDeleted: row.isDeleted,
      deletedAt: row.deletedAt,
    );
  }

  ProxyIpAddressEntity _mapIpAddressRow(ProxyIpAddressesTableData row) {
    return ProxyIpAddressEntity(
      id: row.id,
      ipAddress: row.ipAddress,
      hostname: row.hostname,
      slotId: row.slotId,
      isActive: row.isActive,
      countryCode: row.countryCode,
      cityName: row.cityName,
      ipTimezone: row.ipTimezone,
      highCountryConfidence: row.highCountryConfidence,
      asnName: row.asnName,
      asnNumber: row.asnNumber,
      ipScore: row.ipScore,
      scoreLevel: IpScoreLevel.values.firstWhere(
        (e) => e.name == row.scoreLevel,
        orElse: () => IpScoreLevel.unknown,
      ),
      isVpn: row.isVpn,
      isProxy: row.isProxy,
      isDatacenter: row.isDatacenter,
      isTor: row.isTor,
      isCrawler: row.isCrawler,
      connectionType: row.connectionType,
      isp: row.isp,
      organization: row.organization,
      region: row.region,
      recentAbuse: row.recentAbuse,
      fraudScore: row.fraudScore,
      assignedAt: row.assignedAt,
      removedAt: row.removedAt,
      lastVerification: row.lastVerification,
      lastScoreCheck: row.lastScoreCheck,
      totalDaysUsed: row.totalDaysUsed,
      timesAssigned: row.timesAssigned,
    );
  }
}
