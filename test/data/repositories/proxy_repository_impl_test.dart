import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/data/repositories/proxy_repository_impl.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';

/// Helper to create a test ProxySlotEntity
ProxySlotEntity _makeSlot({
  int? id,
  String? webshareId,
  String slotName = 'Test Slot',
  int slotNumber = 1,
  String username = 'user',
  String password = 'pass',
  int port = 80,
  bool isActive = true,
  bool isDeleted = false,
}) {
  final now = DateTime.now();
  return ProxySlotEntity(
    id: id,
    webshareId: webshareId,
    slotName: slotName,
    slotNumber: slotNumber,
    username: username,
    password: password,
    port: port,
    createdAt: now,
    lastUpdated: now,
    totalIpChanges: 0,
    isActive: isActive,
    isDeleted: isDeleted,
  );
}

/// Helper to create a test ProxyIpAddressEntity
ProxyIpAddressEntity _makeIp({
  int? id,
  String ipAddress = '1.2.3.4',
  required int slotId,
  bool isActive = true,
  double ipScore = 0,
}) {
  final now = DateTime.now();
  return ProxyIpAddressEntity(
    id: id,
    ipAddress: ipAddress,
    hostname: ipAddress,
    slotId: slotId,
    isActive: isActive,
    countryCode: 'US',
    cityName: 'TestCity',
    ipTimezone: 'UTC',
    highCountryConfidence: true,
    asnName: 'TestASN',
    asnNumber: 12345,
    ipScore: ipScore,
    scoreLevel: IpScoreLevel.unknown,
    isVpn: false,
    isProxy: true,
    isDatacenter: false,
    isTor: false,
    fraudScore: 0,
    assignedAt: now,
    lastVerification: now,
    totalDaysUsed: 0,
    timesAssigned: 1,
  );
}

void main() {
  late AppDatabase db;
  late ProxyRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ProxyRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProxyRepositoryImpl - Slot CRUD', () {
    test('insertSlot returns generated ID', () async {
      final id = await repo.insertSlot(_makeSlot(webshareId: 'ws-1'));
      expect(id, greaterThan(0));
    });

    test('getSlotById returns inserted slot', () async {
      final id = await repo.insertSlot(
        _makeSlot(webshareId: 'ws-1', slotName: 'Slot A'),
      );

      final slot = await repo.getSlotById(id);
      expect(slot, isNotNull);
      expect(slot!.slotName, equals('Slot A'));
      expect(slot.webshareId, equals('ws-1'));
    });

    test('getSlotById returns null for non-existent ID', () async {
      final slot = await repo.getSlotById(999);
      expect(slot, isNull);
    });

    test('getSlotByWebshareId finds slot', () async {
      await repo.insertSlot(_makeSlot(webshareId: 'ws-abc'));

      final slot = await repo.getSlotByWebshareId('ws-abc');
      expect(slot, isNotNull);
      expect(slot!.webshareId, equals('ws-abc'));
    });

    test('getSlotByNumber finds slot', () async {
      await repo.insertSlot(_makeSlot(slotNumber: 42));

      final slot = await repo.getSlotByNumber(42);
      expect(slot, isNotNull);
      expect(slot!.slotNumber, equals(42));
    });

    test('getAllSlots excludes soft-deleted', () async {
      await repo.insertSlot(_makeSlot(slotNumber: 1, webshareId: 'a'));
      final id2 =
          await repo.insertSlot(_makeSlot(slotNumber: 2, webshareId: 'b'));
      await repo.softDeleteSlot(id2);

      final slots = await repo.getAllSlots();
      expect(slots.length, equals(1));
      expect(slots.first.slotNumber, equals(1));
    });

    test('getAllSlotsIncludingDeleted includes soft-deleted', () async {
      await repo.insertSlot(_makeSlot(slotNumber: 1, webshareId: 'a'));
      final id2 =
          await repo.insertSlot(_makeSlot(slotNumber: 2, webshareId: 'b'));
      await repo.softDeleteSlot(id2);

      final slots = await repo.getAllSlotsIncludingDeleted();
      expect(slots.length, equals(2));
    });

    test('updateSlot modifies fields', () async {
      final id = await repo.insertSlot(
        _makeSlot(webshareId: 'ws-1', slotName: 'Original'),
      );

      var slot = await repo.getSlotById(id);
      await repo.updateSlot(slot!.copyWith(slotName: 'Updated'));

      slot = await repo.getSlotById(id);
      expect(slot!.slotName, equals('Updated'));
    });

    test('updateSlot throws for slot without ID', () async {
      final slotWithNoId = _makeSlot();
      expect(
        () => repo.updateSlot(slotWithNoId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteSlot permanently removes slot and related IPs', () async {
      final slotId = await repo.insertSlot(_makeSlot(webshareId: 'ws-del'));
      await repo.insertIpAddress(_makeIp(slotId: slotId));

      await repo.deleteSlot(slotId);

      expect(await repo.getSlotById(slotId), isNull);
      expect(await repo.getIpAddressesForSlot(slotId), isEmpty);
    });
  });

  group('ProxyRepositoryImpl - Soft delete & recovery', () {
    test('softDeleteSlot marks slot as deleted and inactive', () async {
      final id = await repo.insertSlot(_makeSlot(webshareId: 'ws-sd'));
      await repo.softDeleteSlot(id);

      final slot = await repo.getSlotById(id);
      expect(slot, isNotNull);
      expect(slot!.isDeleted, isTrue);
      expect(slot.isActive, isFalse);
      expect(slot.deletedAt, isNotNull);
    });

    test('recoverSlot restores a soft-deleted slot', () async {
      final id = await repo.insertSlot(_makeSlot(webshareId: 'ws-rec'));
      await repo.softDeleteSlot(id);
      await repo.recoverSlot(id);

      final slot = await repo.getSlotById(id);
      expect(slot, isNotNull);
      expect(slot!.isDeleted, isFalse);
      expect(slot.deletedAt, isNull);
    });
  });

  group('ProxyRepositoryImpl - Upsert', () {
    test('upsertSlot inserts new slot when no match', () async {
      final id = await repo.upsertSlot(_makeSlot(webshareId: 'ws-new'));
      expect(id, greaterThan(0));

      final slot = await repo.getSlotById(id);
      expect(slot, isNotNull);
    });

    test('upsertSlot updates existing slot by webshareId', () async {
      final originalId =
          await repo.insertSlot(_makeSlot(webshareId: 'ws-up', slotName: 'V1'));

      final upsertId = await repo.upsertSlot(
        _makeSlot(webshareId: 'ws-up', slotName: 'V2'),
      );

      expect(upsertId, equals(originalId));
      final slot = await repo.getSlotById(upsertId);
      expect(slot!.slotName, equals('V2'));
    });
  });

  group('ProxyRepositoryImpl - IP Address management', () {
    late int slotId;

    setUp(() async {
      slotId = await repo.insertSlot(_makeSlot(webshareId: 'ws-ip'));
    });

    test('insertIpAddress returns generated ID', () async {
      final ipId = await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1'),
      );
      expect(ipId, greaterThan(0));
    });

    test('getIpAddressesForSlot returns IPs for correct slot', () async {
      await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1'),
      );
      await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.2'),
      );

      final ips = await repo.getIpAddressesForSlot(slotId);
      expect(ips.length, equals(2));
    });

    test('getActiveIpForSlot returns only active IP', () async {
      await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1', isActive: true),
      );
      await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.2', isActive: false),
      );

      final activeIp = await repo.getActiveIpForSlot(slotId);
      expect(activeIp, isNotNull);
      expect(activeIp!.ipAddress, equals('10.0.0.1'));
    });

    test('getActiveIpForSlot returns null when no active IP', () async {
      await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1', isActive: false),
      );

      final activeIp = await repo.getActiveIpForSlot(slotId);
      expect(activeIp, isNull);
    });

    test('deactivateIp marks IP as inactive with removedAt timestamp',
        () async {
      final ipId = await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1', isActive: true),
      );

      await repo.deactivateIp(ipId);

      final ip = await repo.getIpAddressById(ipId);
      expect(ip, isNotNull);
      expect(ip!.isActive, isFalse);
      expect(ip.removedAt, isNotNull);
    });

    test('updateIpAddress modifies fields', () async {
      final ipId = await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1', ipScore: 0),
      );

      var ip = await repo.getIpAddressById(ipId);
      await repo.updateIpAddress(ip!.copyWith(ipScore: 85.0));

      ip = await repo.getIpAddressById(ipId);
      expect(ip!.ipScore, equals(85.0));
    });

    test('updateIpAddress throws for IP without ID', () async {
      final ipWithNoId = _makeIp(slotId: slotId);
      expect(
        () => repo.updateIpAddress(ipWithNoId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteIpAddress permanently removes IP', () async {
      final ipId = await repo.insertIpAddress(
        _makeIp(slotId: slotId, ipAddress: '10.0.0.1'),
      );

      await repo.deleteIpAddress(ipId);

      final ip = await repo.getIpAddressById(ipId);
      expect(ip, isNull);
    });

    test('getAllIpAddresses returns all IPs across slots', () async {
      final slotId2 =
          await repo.insertSlot(_makeSlot(slotNumber: 2, webshareId: 'ws-ip2'));

      await repo
          .insertIpAddress(_makeIp(slotId: slotId, ipAddress: '10.0.0.1'));
      await repo
          .insertIpAddress(_makeIp(slotId: slotId2, ipAddress: '10.0.0.2'));

      final allIps = await repo.getAllIpAddresses();
      expect(allIps.length, equals(2));
    });
  });

  group('ProxyRepositoryImpl - watchAllSlots', () {
    test('emits current slots', () async {
      await repo.insertSlot(_makeSlot(slotNumber: 1, webshareId: 'ws-w1'));
      await repo.insertSlot(_makeSlot(slotNumber: 2, webshareId: 'ws-w2'));

      final slots = await repo.watchAllSlots().first;
      expect(slots.length, equals(2));
    });

    test('excludes soft-deleted slots', () async {
      await repo.insertSlot(_makeSlot(slotNumber: 1, webshareId: 'ws-w1'));
      final id2 =
          await repo.insertSlot(_makeSlot(slotNumber: 2, webshareId: 'ws-w2'));
      await repo.softDeleteSlot(id2);

      final slots = await repo.watchAllSlots().first;
      expect(slots.length, equals(1));
    });
  });
}
