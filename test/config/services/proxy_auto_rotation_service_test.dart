import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/proxy/scored_ip_result.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

class MockReplacementService extends Mock implements ProxyReplacementService {}

class MockWebshareService extends Mock implements WebshareService {}

class MockIpqsService extends Mock implements IpqsService {}

class MockProxyRepository extends Mock implements ProxyRepository {}

class MockProxySyncService extends Mock implements ProxySyncService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAppConfigService extends Mock implements AppConfigService {}

void main() {
  late MockReplacementService mockReplacement;
  late MockWebshareService mockWebshare;
  late MockIpqsService mockIpqs;
  late MockProxyRepository mockProxyRepo;
  late MockProxySyncService mockSync;
  late MockNotificationService mockNotification;
  late MockAppConfigService mockConfig;
  late ProxyAutoRotationService service;

  final now = DateTime(2026, 3, 13);

  ProxySlotEntity makeSlot(int id, String name) => ProxySlotEntity(
        id: id,
        webshareId: 'ws-$id',
        slotName: name,
        slotNumber: id,
        username: 'user$id',
        password: 'pass$id',
        port: 80,
        createdAt: now,
        lastUpdated: now,
        totalIpChanges: 0,
        isActive: true,
      );

  ProxyIpAddressEntity makeIp(int id, int slotId, String address,
          {double ipScore = 0}) =>
      ProxyIpAddressEntity(
        id: id,
        ipAddress: address,
        hostname: address,
        slotId: slotId,
        isActive: true,
        countryCode: 'US',
        cityName: 'New York',
        ipTimezone: 'UTC',
        highCountryConfidence: true,
        asnName: 'Test ASN',
        asnNumber: 12345,
        ipScore: ipScore,
        scoreLevel: ProxyIpAddressEntity.getScoreLevel(ipScore),
        isVpn: false,
        isProxy: true,
        isDatacenter: false,
        isTor: false,
        fraudScore: 100 - ipScore,
        abuseConfidence: 0,
        assignedAt: now,
        lastVerification: now,
        lastScoreCheck: now,
        totalDaysUsed: 1,
        timesAssigned: 1,
      );

  ScoredIpResult makeResult(int slotId, String name, double score) {
    final slot = makeSlot(slotId, name);
    final ip = makeIp(slotId * 10, slotId, '1.2.3.$slotId', ipScore: score);
    return ScoredIpResult(ip: ip, slot: slot, score: score);
  }

  WebsharePlanInfo makePlan({int available = 10, int total = 20}) =>
      WebsharePlanInfo(
        id: 1,
        status: 'active',
        proxyCount: 5,
        proxyReplacementsTotal: total,
        proxyReplacementsUsed: total - available,
        proxyReplacementsAvailable: available,
        onDemandRefreshesTotal: 100,
        onDemandRefreshesUsed: 0,
        onDemandRefreshesAvailable: 100,
      );

  setUpAll(() {
    registerFallbackValue(ProxyIpAddressEntity.empty());
    registerFallbackValue(NotificationEntity(
      type: NotificationType.rotationCompleted,
      severity: NotificationSeverity.info,
      title: '',
      message: '',
      createdAt: DateTime.now(),
    ));
    registerFallbackValue(NotificationType.rotationCompleted);
    registerFallbackValue(NotificationSeverity.info);
  });

  setUp(() {
    mockReplacement = MockReplacementService();
    mockWebshare = MockWebshareService();
    mockIpqs = MockIpqsService();
    mockProxyRepo = MockProxyRepository();
    mockSync = MockProxySyncService();
    mockNotification = MockNotificationService();
    mockConfig = MockAppConfigService();

    // Default stubs for config observables
    when(() => mockConfig.autoRotationEnabled).thenReturn(true.obs);
    when(() => mockConfig.autoRotationThreshold).thenReturn(40.obs);
    when(() => mockWebshare.isConfigured).thenReturn(true.obs);

    // Default stub for notification service
    when(() => mockNotification.createNotification(
          type: any(named: 'type'),
          severity: any(named: 'severity'),
          title: any(named: 'title'),
          message: any(named: 'message'),
        )).thenAnswer((_) async {});

    service = ProxyAutoRotationService(
      replacementService: mockReplacement,
      webshareService: mockWebshare,
      ipqsService: mockIpqs,
      proxyRepository: mockProxyRepo,
      syncService: mockSync,
      notificationService: mockNotification,
      configService: mockConfig,
    );
  });

  group('ProxyAutoRotationService', () {
    test('skips when auto-rotation is disabled', () async {
      when(() => mockConfig.autoRotationEnabled).thenReturn(false.obs);

      await service.processScoreResults([makeResult(1, 'Slot 1', 20)]);

      verifyNever(() => mockReplacement.fetchPlanInfo());
      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('skips when webshare is not configured', () async {
      when(() => mockWebshare.isConfigured).thenReturn(false.obs);

      await service.processScoreResults([makeResult(1, 'Slot 1', 20)]);

      verifyNever(() => mockReplacement.fetchPlanInfo());
      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('skips IPs above threshold', () async {
      // Threshold is 40, score is 80 => above threshold, should skip
      await service.processScoreResults([makeResult(1, 'Slot 1', 80)]);

      verifyNever(() => mockReplacement.fetchPlanInfo());
      verifyNever(() => mockReplacement.replaceProxyIp(any()));
    });

    test('replaces IPs below threshold, worst first', () async {
      // Two IPs below threshold (40): score 20 and score 30
      final results = [
        makeResult(2, 'Slot 2', 30),
        makeResult(1, 'Slot 1', 20),
      ];

      when(() => mockReplacement.fetchPlanInfo())
          .thenAnswer((_) async => makePlan(available: 10));

      when(() => mockReplacement.replaceProxyIp(any(),
              keepSameCountry: any(named: 'keepSameCountry')))
          .thenAnswer((_) async => Result.success(null));

      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});

      // After replacement, return new IPs with good scores
      when(() => mockProxyRepo.getActiveIpForSlot(1))
          .thenAnswer((_) async => makeIp(100, 1, '5.5.5.1', ipScore: 80));
      when(() => mockProxyRepo.getActiveIpForSlot(2))
          .thenAnswer((_) async => makeIp(200, 2, '5.5.5.2', ipScore: 80));

      // fraudScore: 20 => normalizedScore: 80 (above threshold)
      when(() => mockIpqs.scoreIp(any())).thenAnswer((_) async => IpqsResult(
            success: true,
            fraudScore: 20,
          ));

      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});

      await service.processScoreResults(results);

      // Verify replacements happened
      final capturedIps = verify(() => mockReplacement.replaceProxyIp(
            captureAny(),
            keepSameCountry: true,
          )).captured;

      // Should be worst first: slot 1 (score 20) then slot 2 (score 30)
      expect(capturedIps.length, 2);
      expect((capturedIps[0] as ProxyIpAddressEntity).slotId, 1);
      expect((capturedIps[1] as ProxyIpAddressEntity).slotId, 2);

      // Should get a success summary notification
      verify(() => mockNotification.createNotification(
            type: NotificationType.rotationCompleted,
            severity: NotificationSeverity.info,
            title: 'Auto-Rotation Complete',
            message: any(named: 'message'),
          )).called(1);
    });

    test('stops and notifies on quota exhaustion', () async {
      final results = [
        makeResult(1, 'Slot 1', 10),
        makeResult(2, 'Slot 2', 20),
      ];

      // Quota exhausted from the start
      when(() => mockReplacement.fetchPlanInfo())
          .thenAnswer((_) async => makePlan(available: 0, total: 20));

      await service.processScoreResults(results);

      // Should NOT attempt any replacements
      verifyNever(() => mockReplacement.replaceProxyIp(any(),
          keepSameCountry: any(named: 'keepSameCountry')));

      // Should send quota exhausted notification
      verify(() => mockNotification.createNotification(
            type: NotificationType.quotaExhausted,
            severity: NotificationSeverity.error,
            title: 'Replacement Quota Exhausted',
            message: any(named: 'message'),
          )).called(1);
    });

    test('does not retry when new IP is also below threshold', () async {
      final results = [makeResult(1, 'Slot 1', 20)];

      when(() => mockReplacement.fetchPlanInfo())
          .thenAnswer((_) async => makePlan(available: 10));

      when(() => mockReplacement.replaceProxyIp(any(),
              keepSameCountry: any(named: 'keepSameCountry')))
          .thenAnswer((_) async => Result.success(null));

      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});

      // New IP is also below threshold (score 30 < 40)
      when(() => mockProxyRepo.getActiveIpForSlot(1))
          .thenAnswer((_) async => makeIp(100, 1, '9.9.9.1', ipScore: 30));

      // fraudScore: 70 => normalizedScore: 30 (below threshold of 40)
      when(() => mockIpqs.scoreIp('9.9.9.1'))
          .thenAnswer((_) async => IpqsResult(success: true, fraudScore: 70));

      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});

      await service.processScoreResults(results);

      // Should only replace once (no infinite loop)
      verify(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .called(1);

      // Should send warning about new IP below threshold
      verify(() => mockNotification.createNotification(
            type: NotificationType.rotationFailed,
            severity: NotificationSeverity.warning,
            title: 'New IP Below Threshold',
            message: any(named: 'message'),
          )).called(1);

      // Summary notification: all failures
      verify(() => mockNotification.createNotification(
            type: NotificationType.rotationFailed,
            severity: NotificationSeverity.warning,
            title: 'Auto-Rotation Failed',
            message: any(named: 'message'),
          )).called(1);
    });

    test('handles replacement failure gracefully', () async {
      final results = [makeResult(1, 'Slot 1', 20)];

      when(() => mockReplacement.fetchPlanInfo())
          .thenAnswer((_) async => makePlan(available: 10));

      when(() => mockReplacement.replaceProxyIp(any(),
              keepSameCountry: any(named: 'keepSameCountry')))
          .thenAnswer((_) async => Result.failure('API error'));

      await service.processScoreResults(results);

      // Should send failure summary
      verify(() => mockNotification.createNotification(
            type: NotificationType.rotationFailed,
            severity: NotificationSeverity.warning,
            title: 'Auto-Rotation Failed',
            message: any(named: 'message'),
          )).called(1);
    });

    test('quota exhaustion mid-cycle stops remaining replacements', () async {
      final results = [
        makeResult(1, 'Slot 1', 10),
        makeResult(2, 'Slot 2', 20),
        makeResult(3, 'Slot 3', 30),
      ];

      int fetchCount = 0;
      when(() => mockReplacement.fetchPlanInfo()).thenAnswer((_) async {
        fetchCount++;
        // First call: 1 replacement available, second call: exhausted
        if (fetchCount == 1) return makePlan(available: 1);
        return makePlan(available: 0, total: 20);
      });

      when(() => mockReplacement.replaceProxyIp(any(),
              keepSameCountry: any(named: 'keepSameCountry')))
          .thenAnswer((_) async => Result.success(null));

      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});

      // New IP scores above threshold
      when(() => mockProxyRepo.getActiveIpForSlot(any()))
          .thenAnswer((_) async => makeIp(100, 1, '9.9.9.9', ipScore: 80));

      when(() => mockIpqs.scoreIp(any())).thenAnswer((_) async => IpqsResult(
            success: true,
            fraudScore: 20,
          ));

      when(() => mockProxyRepo.updateIpAddress(any())).thenAnswer((_) async {});

      await service.processScoreResults(results);

      // Only 1 replacement should happen (first slot), then quota exhausted
      verify(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .called(1);

      // Quota exhausted notification
      verify(() => mockNotification.createNotification(
            type: NotificationType.quotaExhausted,
            severity: NotificationSeverity.error,
            title: 'Replacement Quota Exhausted',
            message: any(named: 'message'),
          )).called(1);
    });

    test('skips IPs with null slot id', () async {
      // Create a result with a slot that has no id
      final slot = ProxySlotEntity(
        id: null,
        slotName: 'No ID Slot',
        slotNumber: 0,
        username: 'user',
        password: 'pass',
        port: 80,
        createdAt: now,
        lastUpdated: now,
        totalIpChanges: 0,
        isActive: true,
      );
      final ip = makeIp(10, 0, '1.2.3.4', ipScore: 10);
      final result = ScoredIpResult(ip: ip, slot: slot, score: 10);

      await service.processScoreResults([result]);

      verifyNever(() => mockReplacement.fetchPlanInfo());
    });

    test('concurrent call is skipped while running', () async {
      // Simulate a slow replacement that takes time
      final results = [makeResult(1, 'Slot 1', 20)];

      when(() => mockReplacement.fetchPlanInfo())
          .thenAnswer((_) async => makePlan(available: 10));

      when(() => mockReplacement.replaceProxyIp(any(),
              keepSameCountry: any(named: 'keepSameCountry')))
          .thenAnswer((_) async {
        // Simulate slow operation
        await Future.delayed(const Duration(milliseconds: 100));
        return Result.success(null);
      });

      when(() => mockSync.syncWithWebshare()).thenAnswer((_) async {});

      when(() => mockProxyRepo.getActiveIpForSlot(any()))
          .thenAnswer((_) async => null);

      // Start first call (will be slow)
      final first = service.processScoreResults(results);

      // Start second call immediately (should be skipped)
      final second = service.processScoreResults(results);

      await Future.wait([first, second]);

      // Only one replacement should have occurred
      verify(() => mockReplacement.replaceProxyIp(any(), keepSameCountry: true))
          .called(1);
    });
  });
}
