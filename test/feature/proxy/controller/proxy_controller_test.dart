import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';

/// ProxyController uses `Get.find<DatabaseService>()` and `Get.find<WebshareService>()`
/// in onInit, which makes it difficult to test via Get.put(). Instead, we test
/// the controller's pure logic methods by constructing it directly and populating
/// its observable lists manually (bypassing onInit).
void main() {
  late ProxyController controller;

  final now = DateTime.now();

  ProxySlotEntity makeSlot({
    int? id,
    int slotNumber = 1,
    String slotName = 'Slot 1',
    bool isActive = true,
    int? currentIpAddressId,
  }) {
    return ProxySlotEntity(
      id: id,
      slotName: slotName,
      slotNumber: slotNumber,
      username: 'user',
      password: 'pass',
      port: 80,
      createdAt: now,
      lastUpdated: now,
      totalIpChanges: 0,
      isActive: isActive,
      currentIpAddressId: currentIpAddressId,
    );
  }

  ProxyIpAddressEntity makeIp({
    int? id,
    String ipAddress = '1.2.3.4',
    int slotId = 1,
    bool isActive = true,
    double ipScore = 0,
    String countryCode = 'US',
    String cityName = 'TestCity',
  }) {
    return ProxyIpAddressEntity(
      id: id,
      ipAddress: ipAddress,
      hostname: ipAddress,
      slotId: slotId,
      isActive: isActive,
      countryCode: countryCode,
      cityName: cityName,
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
      abuseConfidence: 0,
      assignedAt: now,
      lastVerification: now,
      totalDaysUsed: 0,
      timesAssigned: 1,
    );
  }

  setUp(() {
    Get.testMode = true;
    // Create controller but don't call onInit (which needs DI services)
    controller = ProxyController();
  });

  tearDown(() {
    Get.reset();
  });

  group('ProxyController - selectSlot', () {
    test('sets selectedSlot and loads IP history', () {
      final slot = makeSlot(id: 1, slotNumber: 1);
      final ip1 = makeIp(id: 10, slotId: 1, ipAddress: '1.1.1.1');
      final ip2 =
          makeIp(id: 11, slotId: 1, ipAddress: '2.2.2.2', isActive: false);

      controller.proxySlots.addAll([slot]);
      controller.ipAddresses.addAll([ip1, ip2]);

      controller.selectSlot(slot);

      expect(controller.selectedSlot.value, equals(slot));
      expect(controller.selectedSlotIpHistory.length, equals(2));
    });

    test('clearSelection resets selectedSlot and history', () {
      final slot = makeSlot(id: 1, slotNumber: 1);
      controller.proxySlots.add(slot);
      controller.selectSlot(slot);

      controller.clearSelection();

      expect(controller.selectedSlot.value, isNull);
      expect(controller.selectedSlotIpHistory, isEmpty);
    });
  });

  group('ProxyController - getCurrentIpForSlot', () {
    test('returns IP by currentIpAddressId', () {
      final ip = makeIp(id: 10, slotId: 1, ipAddress: '1.1.1.1');
      final slot = makeSlot(id: 1, slotNumber: 1, currentIpAddressId: 10);

      controller.ipAddresses.add(ip);

      final result = controller.getCurrentIpForSlot(slot);
      expect(result, isNotNull);
      expect(result!.ipAddress, equals('1.1.1.1'));
    });

    test('falls back to active IP for slot when no currentIpAddressId', () {
      final ip = makeIp(id: 10, slotId: 1, ipAddress: '3.3.3.3');
      final slot = makeSlot(id: 1, slotNumber: 1);

      controller.ipAddresses.add(ip);

      final result = controller.getCurrentIpForSlot(slot);
      expect(result, isNotNull);
      expect(result!.ipAddress, equals('3.3.3.3'));
    });

    test('returns null when no matching IP exists', () {
      final slot = makeSlot(id: 1, slotNumber: 1);
      final result = controller.getCurrentIpForSlot(slot);
      expect(result, isNull);
    });
  });

  group('ProxyController - getIpHistoryForSlot', () {
    test('returns IPs for slot sorted by assignedAt descending', () {
      final older = makeIp(
        id: 10,
        slotId: 1,
        ipAddress: '1.1.1.1',
        isActive: false,
      ).copyWith(assignedAt: DateTime(2025, 1, 1));
      final newer = makeIp(
        id: 11,
        slotId: 1,
        ipAddress: '2.2.2.2',
      ).copyWith(assignedAt: DateTime(2025, 6, 1));

      controller.ipAddresses.addAll([older, newer]);

      final history = controller.getIpHistoryForSlot(1);
      expect(history.length, equals(2));
      expect(history.first.ipAddress, equals('2.2.2.2'));
      expect(history.last.ipAddress, equals('1.1.1.1'));
    });

    test('returns empty list for slot with no IPs', () {
      final history = controller.getIpHistoryForSlot(999);
      expect(history, isEmpty);
    });
  });

  group('ProxyController - getFilteredSlots', () {
    test('filters by active when showOnlyActive is true', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, isActive: true),
        makeSlot(id: 2, slotNumber: 2, isActive: false),
      ]);
      controller.showOnlyActive.value = true;

      final filtered = controller.getFilteredSlots();
      expect(filtered.length, equals(1));
      expect(filtered.first.slotNumber, equals(1));
    });

    test('shows all when showOnlyActive is false', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, isActive: true),
        makeSlot(id: 2, slotNumber: 2, isActive: false),
      ]);
      controller.showOnlyActive.value = false;

      final filtered = controller.getFilteredSlots();
      expect(filtered.length, equals(2));
    });

    test('filters by search query on slot name', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, slotName: 'Alpha Slot'),
        makeSlot(id: 2, slotNumber: 2, slotName: 'Beta Slot'),
      ]);
      controller.showOnlyActive.value = false;
      controller.searchQuery.value = 'alpha';

      final filtered = controller.getFilteredSlots();
      expect(filtered.length, equals(1));
      expect(filtered.first.slotName, equals('Alpha Slot'));
    });

    test('filters by search query on IP address', () {
      final slot = makeSlot(id: 1, slotNumber: 1, currentIpAddressId: 10);
      final ip = makeIp(id: 10, slotId: 1, ipAddress: '99.88.77.66');

      controller.proxySlots.add(slot);
      controller.ipAddresses.add(ip);
      controller.showOnlyActive.value = false;
      controller.searchQuery.value = '99.88';

      final filtered = controller.getFilteredSlots();
      expect(filtered.length, equals(1));
    });

    test('sorts by IP score when requested', () {
      final slot1 = makeSlot(id: 1, slotNumber: 1, currentIpAddressId: 10);
      final slot2 = makeSlot(id: 2, slotNumber: 2, currentIpAddressId: 20);
      final ip1 = makeIp(id: 10, slotId: 1, ipScore: 30);
      final ip2 = makeIp(id: 20, slotId: 2, ipScore: 90);

      controller.proxySlots.addAll([slot1, slot2]);
      controller.ipAddresses.addAll([ip1, ip2]);
      controller.showOnlyActive.value = false;

      final sorted = controller.getFilteredSlots(sortByScore: true);
      expect(sorted.first.slotNumber, equals(2)); // Higher score first
    });
  });

  group('ProxyController - statistics', () {
    test('totalSlots returns count of all proxy slots', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1),
        makeSlot(id: 2, slotNumber: 2),
      ]);
      expect(controller.totalSlots, equals(2));
    });

    test('activeSlots returns count of active slots only', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, isActive: true),
        makeSlot(id: 2, slotNumber: 2, isActive: false),
        makeSlot(id: 3, slotNumber: 3, isActive: true),
      ]);
      expect(controller.activeSlots, equals(2));
    });

    test('totalIpChanges sums all slot changes', () {
      controller.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1).copyWith(totalIpChanges: 3),
        makeSlot(id: 2, slotNumber: 2).copyWith(totalIpChanges: 5),
      ]);
      expect(controller.totalIpChanges, equals(8));
    });
  });

  group('ProxyController - observable initial states', () {
    test('initial states are correct', () {
      expect(controller.isLoading.value, isTrue);
      expect(controller.isSyncing.value, isFalse);
      expect(controller.proxySlots, isEmpty);
      expect(controller.ipAddresses, isEmpty);
      expect(controller.selectedSlot.value, isNull);
      expect(controller.selectedSlotIpHistory, isEmpty);
      expect(controller.isWebshareConfigured.value, isFalse);
      expect(controller.lastSyncError.value, isNull);
    });
  });
}
