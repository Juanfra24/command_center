import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/config/services/webshare/webshare_models.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

import '../../helpers/test_helpers.dart';

/// Helper to create a test WebshareProxySlot
WebshareProxySlot _makeWebshareSlot({
  String id = 'ws-1',
  int slotNumber = 1,
  String username = 'user',
  String password = 'pass',
  String proxyAddress = '1.2.3.4',
  int port = 80,
  bool valid = true,
  String countryCode = 'US',
  String cityName = 'TestCity',
}) {
  return WebshareProxySlot(
    id: id,
    username: username,
    password: password,
    proxyAddress: proxyAddress,
    port: port,
    valid: valid,
    countryCode: countryCode,
    cityName: cityName,
    createdAt: DateTime(2025, 1, 1),
    slotNumber: slotNumber,
  );
}

/// Helper to create a test ProxySlotEntity
ProxySlotEntity _makeSlotEntity({
  int? id,
  String? webshareId,
  int slotNumber = 1,
  bool isDeleted = false,
  bool isActive = true,
}) {
  final now = DateTime.now();
  return ProxySlotEntity(
    id: id,
    webshareId: webshareId,
    slotName: 'Slot $slotNumber',
    slotNumber: slotNumber,
    username: 'user',
    password: 'pass',
    port: 80,
    createdAt: now,
    lastUpdated: now,
    totalIpChanges: 0,
    isActive: isActive,
    isDeleted: isDeleted,
  );
}

void main() {
  late ProxySyncService syncService;
  late MockProxyRepository mockRepo;
  late MockWebshareService mockWebshare;

  setUp(() {
    mockRepo = MockProxyRepository();
    mockWebshare = MockWebshareService();
    syncService = ProxySyncService(mockRepo, mockWebshare);
  });

  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(_makeSlotEntity());
    registerFallbackValue(ProxyIpAddressEntity.empty());
  });

  group('ProxySyncService - syncWithWebshare', () {
    test('creates new slots for new webshare proxies', () async {
      final wsProxies = [
        _makeWebshareSlot(id: 'ws-new', slotNumber: 1),
      ];

      when(() => mockWebshare.getProxyList())
          .thenAnswer((_) async => wsProxies);
      when(() => mockRepo.getAllSlotsIncludingDeleted())
          .thenAnswer((_) async => []);
      when(() => mockRepo.insertSlot(any())).thenAnswer((_) async => 1);
      when(() => mockRepo.insertIpAddress(any())).thenAnswer((_) async => 10);
      when(() => mockRepo.getSlotById(1)).thenAnswer(
          (_) async => _makeSlotEntity(id: 1, webshareId: 'ws-new'));
      when(() => mockRepo.updateSlot(any())).thenAnswer((_) async {});

      await syncService.syncWithWebshare();

      verify(() => mockRepo.insertSlot(any())).called(1);
      verify(() => mockRepo.insertIpAddress(any())).called(1);
    });

    test('updates existing slots with matching webshareId', () async {
      final wsProxies = [
        _makeWebshareSlot(
            id: 'ws-existing', slotNumber: 1, username: 'new-user'),
      ];

      final existingSlot =
          _makeSlotEntity(id: 1, webshareId: 'ws-existing', slotNumber: 1);

      when(() => mockWebshare.getProxyList())
          .thenAnswer((_) async => wsProxies);
      when(() => mockRepo.getAllSlotsIncludingDeleted())
          .thenAnswer((_) async => [existingSlot]);
      when(() => mockRepo.updateSlot(any())).thenAnswer((_) async {});
      when(() => mockRepo.getActiveIpForSlot(1)).thenAnswer((_) async =>
          ProxyIpAddressEntity.empty().copyWith(
            id: 10,
            ipAddress: '1.2.3.4',
            slotId: 1,
            isActive: true,
          ));

      await syncService.syncWithWebshare();

      verify(() => mockRepo.updateSlot(any())).called(1);
      verifyNever(() => mockRepo.insertSlot(any()));
    });

    test('recovers soft-deleted slots found in API', () async {
      final wsProxies = [
        _makeWebshareSlot(id: 'ws-deleted', slotNumber: 1),
      ];

      final deletedSlot = _makeSlotEntity(
        id: 1,
        webshareId: 'ws-deleted',
        slotNumber: 1,
        isDeleted: true,
      );

      when(() => mockWebshare.getProxyList())
          .thenAnswer((_) async => wsProxies);
      when(() => mockRepo.getAllSlotsIncludingDeleted())
          .thenAnswer((_) async => [deletedSlot]);
      when(() => mockRepo.recoverSlot(1)).thenAnswer((_) async {});
      when(() => mockRepo.updateSlot(any())).thenAnswer((_) async {});
      when(() => mockRepo.getActiveIpForSlot(1)).thenAnswer((_) async =>
          ProxyIpAddressEntity.empty().copyWith(
            id: 10,
            ipAddress: '1.2.3.4',
            slotId: 1,
            isActive: true,
          ));

      await syncService.syncWithWebshare();

      verify(() => mockRepo.recoverSlot(1)).called(1);
    });

    test('soft-deletes DB slots not found in API response', () async {
      // API returns nothing
      when(() => mockWebshare.getProxyList()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllSlotsIncludingDeleted()).thenAnswer(
        (_) async => [
          _makeSlotEntity(id: 1, webshareId: 'ws-stale', isDeleted: false),
        ],
      );
      when(() => mockRepo.softDeleteSlot(1)).thenAnswer((_) async {});

      await syncService.syncWithWebshare();

      verify(() => mockRepo.softDeleteSlot(1)).called(1);
    });

    test('does not soft-delete manually added slots (no webshareId)', () async {
      when(() => mockWebshare.getProxyList()).thenAnswer((_) async => []);
      when(() => mockRepo.getAllSlotsIncludingDeleted()).thenAnswer(
        (_) async => [
          _makeSlotEntity(id: 1, webshareId: null),
        ],
      );

      await syncService.syncWithWebshare();

      verifyNever(() => mockRepo.softDeleteSlot(any()));
    });

    test('handles IP change during update', () async {
      final wsProxies = [
        _makeWebshareSlot(
            id: 'ws-ip-change', slotNumber: 1, proxyAddress: '5.6.7.8'),
      ];

      final existingSlot =
          _makeSlotEntity(id: 1, webshareId: 'ws-ip-change');

      when(() => mockWebshare.getProxyList())
          .thenAnswer((_) async => wsProxies);
      when(() => mockRepo.getAllSlotsIncludingDeleted())
          .thenAnswer((_) async => [existingSlot]);
      when(() => mockRepo.updateSlot(any())).thenAnswer((_) async {});
      // Current IP is different from the new one in API
      when(() => mockRepo.getActiveIpForSlot(1)).thenAnswer((_) async =>
          ProxyIpAddressEntity.empty().copyWith(
            id: 10,
            ipAddress: '1.2.3.4',
            slotId: 1,
            isActive: true,
          ));
      when(() => mockRepo.deactivateIp(10)).thenAnswer((_) async {});
      when(() => mockRepo.insertIpAddress(any())).thenAnswer((_) async => 20);

      await syncService.syncWithWebshare();

      verify(() => mockRepo.deactivateIp(10)).called(1);
      verify(() => mockRepo.insertIpAddress(any())).called(1);
    });
  });
}
