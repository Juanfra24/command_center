import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_api_client.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late ProxyScoringController scoringController;
  late MockProxyRepository mockProxyRepo;
  late MockIpqsService mockIpqsService;
  late ProxyController proxyController;

  final now = DateTime.now();

  ProxySlotEntity makeSlot({
    int? id,
    int slotNumber = 1,
    int? currentIpAddressId,
    bool isActive = true,
  }) {
    return ProxySlotEntity(
      id: id,
      slotName: 'Slot $slotNumber',
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
    double fraudScore = 0,
    DateTime? lastScoreCheck,
  }) {
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
      scoreLevel: ProxyIpAddressEntity.getScoreLevel(ipScore),
      isVpn: false,
      isProxy: true,
      isDatacenter: false,
      isTor: false,
      fraudScore: fraudScore,
      assignedAt: now,
      lastVerification: now,
      lastScoreCheck: lastScoreCheck,
      totalDaysUsed: 0,
      timesAssigned: 1,
    );
  }

  setUpAll(() {
    registerFallbackValue(ProxyIpAddressEntity.empty());
  });

  setUp(() {
    Get.testMode = true;
    mockProxyRepo = MockProxyRepository();
    mockIpqsService = MockIpqsService();
    proxyController = ProxyController();

    // Mock isConfigured as an observable
    when(() => mockIpqsService.isConfigured).thenReturn(true.obs);

    scoringController = ProxyScoringController(
      mockProxyRepo,
      mockIpqsService,
      proxyController,
    );
  });

  tearDown(() {
    Get.reset();
  });

  group('ProxyScoringController - scoreIpWithIpqs', () {
    test('returns false when IPQS not configured', () async {
      when(() => mockIpqsService.isConfigured).thenReturn(false.obs);
      scoringController = ProxyScoringController(
        mockProxyRepo,
        mockIpqsService,
        proxyController,
      );

      final ip = makeIp(id: 1);
      final success = await scoringController.scoreIpWithIpqs(ip);
      expect(success, isFalse);
    });

    test('scores IP and updates repository on success', () async {
      final ip = makeIp(id: 1, ipAddress: '1.2.3.4');

      when(() => mockIpqsService.scoreIp('1.2.3.4')).thenAnswer(
        (_) async => IpqsResult(
          success: true,
          fraudScore: 20,
          isVpn: false,
          isProxy: true,
          isDatacenter: false,
          isTor: false,
          recentAbuse: false,
        ),
      );
      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});

      // Provide ipAddresses for proxyController reload
      when(() => mockProxyRepo.getAllIpAddresses()).thenAnswer((_) async => []);

      final success =
          await scoringController.scoreIpWithIpqs(ip, skipReload: true);
      expect(success, isTrue);
      verify(() => mockProxyRepo.updateIpAddress(any())).called(1);
    });

    test('returns false when IPQS returns failure', () async {
      final ip = makeIp(id: 1, ipAddress: '1.2.3.4');

      when(() => mockIpqsService.scoreIp('1.2.3.4')).thenAnswer(
        (_) async => IpqsResult.error('API error'),
      );

      final success =
          await scoringController.scoreIpWithIpqs(ip, skipReload: true);
      expect(success, isFalse);
    });

    test('sets isScoring during operation', () async {
      final ip = makeIp(id: 1, ipAddress: '1.2.3.4');

      when(() => mockIpqsService.scoreIp('1.2.3.4')).thenAnswer(
        (_) async => IpqsResult.error('fail'),
      );

      expect(scoringController.isScoring.value, isFalse);
      final future = scoringController.scoreIpWithIpqs(ip, skipReload: true);
      // isScoring should be true during execution
      await future;
      expect(scoringController.isScoring.value, isFalse);
    });
  });

  group('ProxyScoringController - statistics', () {
    test('hasScoredIps returns true when at least one IP is scored', () {
      final slot = makeSlot(id: 1, currentIpAddressId: 10);
      final ip = makeIp(
        id: 10,
        slotId: 1,
        ipScore: 80,
        lastScoreCheck: DateTime.now(),
      );

      proxyController.proxySlots.add(slot);
      proxyController.ipAddresses.add(ip);
      proxyController.rebuildIpLookup();
      scoringController.recalculateStatsForTest();

      expect(scoringController.hasScoredIps.value, isTrue);
    });

    test('hasScoredIps returns false when no IPs are scored', () {
      final slot = makeSlot(id: 1, currentIpAddressId: 10);
      final ip = makeIp(id: 10, slotId: 1, ipScore: 0);

      proxyController.proxySlots.add(slot);
      proxyController.ipAddresses.add(ip);
      proxyController.rebuildIpLookup();
      scoringController.recalculateStatsForTest();

      expect(scoringController.hasScoredIps.value, isFalse);
    });

    test('averageFraudScore computes correctly', () {
      proxyController.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, currentIpAddressId: 10),
        makeSlot(id: 2, slotNumber: 2, currentIpAddressId: 20),
      ]);
      proxyController.ipAddresses.addAll([
        makeIp(
            id: 10, slotId: 1, fraudScore: 20, lastScoreCheck: DateTime.now()),
        makeIp(
            id: 20, slotId: 2, fraudScore: 40, lastScoreCheck: DateTime.now()),
      ]);
      proxyController.rebuildIpLookup();
      scoringController.recalculateStatsForTest();

      expect(scoringController.averageFraudScore.value, equals(30.0));
    });

    test('averageFraudScore returns 0 when no scored IPs', () {
      expect(scoringController.averageFraudScore.value, equals(0));
    });

    test('lowScoreCount counts IPs with fraud score above 60', () {
      proxyController.proxySlots.addAll([
        makeSlot(id: 1, slotNumber: 1, currentIpAddressId: 10),
        makeSlot(id: 2, slotNumber: 2, currentIpAddressId: 20),
        makeSlot(id: 3, slotNumber: 3, currentIpAddressId: 30),
      ]);
      proxyController.ipAddresses.addAll([
        makeIp(
            id: 10, slotId: 1, fraudScore: 70, lastScoreCheck: DateTime.now()),
        makeIp(
            id: 20, slotId: 2, fraudScore: 20, lastScoreCheck: DateTime.now()),
        makeIp(
            id: 30, slotId: 3, fraudScore: 80, lastScoreCheck: DateTime.now()),
      ]);
      proxyController.rebuildIpLookup();
      scoringController.recalculateStatsForTest();

      expect(scoringController.lowScoreCount.value, equals(2));
    });
  });

  group('ProxyScoringController - initial state', () {
    test('isScoring starts as false', () {
      expect(scoringController.isScoring.value, isFalse);
    });

    test('sortByScore starts as false', () {
      expect(scoringController.sortByScore.value, isFalse);
    });
  });
}
