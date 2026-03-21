import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/config/services/watchdog/watchdog_handlers.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/domain/entities/notification.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/Status/data/process_model.dart';

class MockBotEngine extends Mock implements BotEngine {}

class MockNativeCommandsService extends Mock implements NativeCommandsService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockProxyAutoRotationService extends Mock
    implements ProxyAutoRotationService {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockProxyRepository extends Mock implements ProxyRepository {}

void main() {
  late MockBotEngine mockBotEngine;
  late MockNativeCommandsService mockNativeCommands;
  late MockNotificationService mockNotificationService;
  late MockProxyAutoRotationService mockAutoRotation;
  late MockAccountRepository mockAccountRepo;
  late MockProxyRepository mockProxyRepo;
  late WatchdogHandlers handlers;

  const defaultConfig = LaunchConfig(scriptName: 'TestScript');

  TrackedClient makeClient({
    String name = 'TestChar',
    int characterId = 1,
    int accountId = 100,
    int? proxySlotId,
    String email = 'test@test.com',
    String password = 'pass123',
    String? proxyUrl,
    LaunchConfig config = defaultConfig,
    int? pid = 1234,
    ClientStatus status = ClientStatus.running,
    DateTime? launchedAt,
    int retryCount = 0,
    int consecutiveQuickDeaths = 0,
    DateTime? lastDeathAt,
  }) {
    return TrackedClient(
      characterName: name,
      characterId: characterId,
      accountId: accountId,
      proxySlotId: proxySlotId,
      email: email,
      password: password,
      proxyUrl: proxyUrl,
      launchConfig: config,
      pid: pid,
      status: status,
      launchedAt: launchedAt,
      retryCount: retryCount,
      consecutiveQuickDeaths: consecutiveQuickDeaths,
      lastDeathAt: lastDeathAt,
    );
  }

  setUpAll(() {
    registerFallbackValue(NotificationType.clientFailed);
    registerFallbackValue(NotificationSeverity.info);
    registerFallbackValue(const LaunchConfig(scriptName: 'fallback'));
    registerFallbackValue(ProxyIpAddressEntity.empty());
  });

  setUp(() {
    mockBotEngine = MockBotEngine();
    mockNativeCommands = MockNativeCommandsService();
    mockNotificationService = MockNotificationService();
    mockAutoRotation = MockProxyAutoRotationService();
    mockAccountRepo = MockAccountRepository();
    mockProxyRepo = MockProxyRepository();

    when(() => mockNotificationService.createNotification(
          type: any(named: 'type'),
          severity: any(named: 'severity'),
          title: any(named: 'title'),
          message: any(named: 'message'),
        )).thenAnswer((_) async {});

    handlers = WatchdogHandlers(
      botEngine: mockBotEngine,
      nativeCommandsService: mockNativeCommands,
      notificationService: mockNotificationService,
      autoRotationService: mockAutoRotation,
      accountRepository: mockAccountRepo,
      proxyRepository: mockProxyRepo,
    );
  });

  group('classifyDeath', () {
    test('normal death sets status to restarting and resets quick deaths', () {
      // Client alive longer than quickDeathThreshold (30s)
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        consecutiveQuickDeaths: 2,
      );

      handlers.classifyDeath(client);

      expect(client.status, ClientStatus.restarting);
      expect(client.consecutiveQuickDeaths, 0);
    });

    test('normal death sets PID to null', () {
      final client = makeClient(
        pid: 5678,
        launchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      handlers.classifyDeath(client);

      expect(client.pid, isNull);
    });

    test('normal death sets lastDeathAt', () {
      final before = DateTime.now();
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      handlers.classifyDeath(client);

      expect(client.lastDeathAt, isNotNull);
      expect(
        client.lastDeathAt!.isAfter(before) ||
            client.lastDeathAt!.isAtSameMomentAs(before),
        isTrue,
      );
    });

    test('quick death sets status to failed and increments quick deaths', () {
      // Client alive less than quickDeathThreshold (30s)
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        consecutiveQuickDeaths: 0,
      );

      handlers.classifyDeath(client);

      expect(client.status, ClientStatus.failed);
      expect(client.consecutiveQuickDeaths, 1);
    });

    test('quick death creates clientFailed notification', () {
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        consecutiveQuickDeaths: 0,
      );

      handlers.classifyDeath(client);

      verify(() => mockNotificationService.createNotification(
            type: NotificationType.clientFailed,
            severity: NotificationSeverity.warning,
            title: 'Client Failed',
            message: any(named: 'message'),
          )).called(1);
    });

    test('quick death sets PID to null', () {
      final client = makeClient(
        pid: 5678,
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      handlers.classifyDeath(client);

      expect(client.pid, isNull);
    });

    test('quick death reaching banEscalationThreshold sets status to banned',
        () {
      // consecutiveQuickDeaths is 2, threshold is 3 — after increment it hits 3
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        consecutiveQuickDeaths: WatchdogService.banEscalationThreshold - 1, // 2
      );

      handlers.classifyDeath(client);

      expect(client.status, ClientStatus.banned);
      expect(client.consecutiveQuickDeaths,
          WatchdogService.banEscalationThreshold);
    });

    test('ban escalation does not create clientFailed notification', () {
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        consecutiveQuickDeaths: WatchdogService.banEscalationThreshold - 1,
      );

      handlers.classifyDeath(client);

      verifyNever(() => mockNotificationService.createNotification(
            type: NotificationType.clientFailed,
            severity: any(named: 'severity'),
            title: any(named: 'title'),
            message: any(named: 'message'),
          ));
    });

    test('quick death exceeding banEscalationThreshold still sets banned', () {
      // Already well past the threshold
      final client = makeClient(
        launchedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        consecutiveQuickDeaths: WatchdogService.banEscalationThreshold + 5,
      );

      handlers.classifyDeath(client);

      expect(client.status, ClientStatus.banned);
    });

    test('null launchedAt treated as zero duration (quick death)', () {
      final client = makeClient(
        launchedAt: null,
        consecutiveQuickDeaths: 0,
      );

      handlers.classifyDeath(client);

      expect(client.status, ClientStatus.failed);
      expect(client.consecutiveQuickDeaths, 1);
    });
  });

  group('handleRestart', () {
    test('max retries reached sets status to stopped and returns true',
        () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: WatchdogService.maxRetries,
      );

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.status, ClientStatus.stopped);
    });

    test('max retries reached creates maxRetriesReached notification',
        () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: WatchdogService.maxRetries,
      );

      await handlers.handleRestart(client);

      verify(() => mockNotificationService.createNotification(
            type: NotificationType.maxRetriesReached,
            severity: NotificationSeverity.error,
            title: 'Max Retries Reached',
            message: any(named: 'message'),
          )).called(1);
    });

    test('still in cooldown returns false with no state change', () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 0,
        lastDeathAt: DateTime.now(), // just died — 30s cooldown required
      );
      final statusBefore = client.status;
      final retryCountBefore = client.retryCount;

      final result = await handlers.handleRestart(client);

      expect(result, isFalse);
      expect(client.status, statusBefore);
      expect(client.retryCount, retryCountBefore);
    });

    test('successful relaunch updates status, PID, and returns true', () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 0,
        pid: null,
        // lastDeathAt long ago so cooldown has passed
        lastDeathAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 9999, statusPort: 8080));

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.status, ClientStatus.running);
      expect(client.pid, 9999);
      expect(client.statusPort, 8080);
      expect(client.retryCount, 1);
      expect(client.launchedAt, isNotNull);
    });

    test('successful relaunch creates clientRelaunched notification', () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 0,
        lastDeathAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 9999, statusPort: 8080));

      await handlers.handleRestart(client);

      verify(() => mockNotificationService.createNotification(
            type: NotificationType.clientRelaunched,
            severity: NotificationSeverity.info,
            title: 'Client Relaunched',
            message: any(named: 'message'),
          )).called(1);
    });

    test('failed relaunch increments retryCount and updates lastDeathAt',
        () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 0,
        lastDeathAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenThrow(Exception('Engine error'));

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.retryCount, 1);
      expect(client.lastDeathAt, isNotNull);
      // Status should NOT be changed to running on failure
      expect(client.status, ClientStatus.restarting);
    });

    test('exponential backoff: cooldown doubles with each retry', () async {
      // retryCount = 0 => cooldown = 30s
      // retryCount = 1 => cooldown = 60s
      // retryCount = 2 => cooldown = 120s
      // retryCount = 3 => cooldown = 240s
      // retryCount = 4 => cooldown = 300s (capped at maxCooldownSeconds)

      // At retryCount=2, cooldown should be 120s.
      // If lastDeathAt was 60s ago, should still be cooling down.
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 2,
        lastDeathAt: DateTime.now().subtract(const Duration(seconds: 60)),
      );

      final result = await handlers.handleRestart(client);

      // 60s < 120s cooldown => still cooling down
      expect(result, isFalse);
    });

    test('exponential backoff: cooldown passed allows restart', () async {
      // At retryCount=1, cooldown should be 60s.
      // If lastDeathAt was 61s ago, cooldown has passed.
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 1,
        lastDeathAt: DateTime.now().subtract(const Duration(seconds: 61)),
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 5555, statusPort: null));

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.status, ClientStatus.running);
    });

    test('exponential backoff: cooldown caps at maxCooldownSeconds', () async {
      // At retryCount=4, raw cooldown = 30 * 2^4 = 480s
      // Capped at maxCooldownSeconds = 300s
      // If lastDeathAt was 301s ago, cooldown has passed.
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 4,
        lastDeathAt: DateTime.now().subtract(const Duration(seconds: 301)),
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 7777, statusPort: null));

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.status, ClientStatus.running);
    });

    test('null lastDeathAt bypasses cooldown check', () async {
      final client = makeClient(
        status: ClientStatus.restarting,
        retryCount: 1,
        lastDeathAt: null,
      );

      when(() => mockBotEngine.launch(
            characterId: any(named: 'characterId'),
            characterName: any(named: 'characterName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            proxyUrl: any(named: 'proxyUrl'),
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 3333, statusPort: null));

      final result = await handlers.handleRestart(client);

      expect(result, isTrue);
      expect(client.status, ClientStatus.running);
    });

    test('launch passes correct client fields to bot engine', () async {
      final client = makeClient(
        name: 'MyChar',
        characterId: 42,
        email: 'user@example.com',
        password: 'secret',
        proxyUrl: 'socks5://u:p@1.2.3.4:1080',
        config: const LaunchConfig(
          scriptName: 'Woodcutter',
          world: '301',
        ),
        status: ClientStatus.restarting,
        retryCount: 0,
        lastDeathAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      when(() => mockBotEngine.launch(
            characterId: 42,
            characterName: 'MyChar',
            email: 'user@example.com',
            password: 'secret',
            proxyUrl: 'socks5://u:p@1.2.3.4:1080',
            config: any(named: 'config'),
          )).thenAnswer((_) async => (pid: 1111, statusPort: null));

      await handlers.handleRestart(client);

      verify(() => mockBotEngine.launch(
            characterId: 42,
            characterName: 'MyChar',
            email: 'user@example.com',
            password: 'secret',
            proxyUrl: 'socks5://u:p@1.2.3.4:1080',
            config: any(named: 'config'),
          )).called(1);
    });
  });

  group('discoverPid', () {
    test('finds PID when command line contains matching profile arg', () {
      final client = makeClient(characterId: 42, pid: null);
      final processes = [
        const ProcessClient(
          commandLine:
              'java -jar microbot.jar --cc-profile-dir=/profiles/bot-42',
          processId: 5678,
        ),
      ];

      final pid = handlers.discoverPid(client, processes);

      expect(pid, 5678);
    });

    test('returns null when no match found', () {
      final client = makeClient(characterId: 42, pid: null);
      final processes = [
        const ProcessClient(
          commandLine:
              'java -jar microbot.jar --cc-profile-dir=/profiles/bot-99',
          processId: 5678,
        ),
      ];

      final pid = handlers.discoverPid(client, processes);

      expect(pid, isNull);
    });

    test('returns null for empty process list', () {
      final client = makeClient(characterId: 42, pid: null);

      final pid = handlers.discoverPid(client, []);

      expect(pid, isNull);
    });

    test('matches first process when multiple match', () {
      final client = makeClient(characterId: 7, pid: null);
      final processes = [
        const ProcessClient(
          commandLine:
              'java -jar microbot.jar --cc-profile-dir=/profiles/bot-7',
          processId: 1000,
        ),
        const ProcessClient(
          commandLine:
              'java -jar microbot.jar --cc-profile-dir=/profiles/bot-7',
          processId: 2000,
        ),
      ];

      final pid = handlers.discoverPid(client, processes);

      expect(pid, 1000);
    });

    test('does not match when profile arg is absent', () {
      final client = makeClient(characterId: 42, pid: null);
      final processes = [
        const ProcessClient(
          commandLine: 'java -jar microbot.jar bot-42',
          processId: 5678,
        ),
      ];

      final pid = handlers.discoverPid(client, processes);

      expect(pid, isNull);
    });

    test('does not match partial characterId', () {
      // characterId = 4, should NOT match bot-42
      final client = makeClient(characterId: 4, pid: null);
      final processes = [
        const ProcessClient(
          commandLine:
              'java -jar microbot.jar --cc-profile-dir=/profiles/bot-42',
          processId: 5678,
        ),
      ];

      final pid = handlers.discoverPid(client, processes);

      expect(pid, isNull, reason: 'bot-4 must not match bot-42');
    });

    test('discoverPid does not match partial character IDs', () {
      final client = makeClient(characterId: 4, pid: null);
      final processes = [
        const ProcessClient(
            processId: 999, commandLine: 'java --cc-profile-dir=/p/bot-42'),
      ];
      final pid = handlers.discoverPid(client, processes);
      expect(pid, isNull, reason: 'bot-4 must not match bot-42');
    });
  });

  group('handleBan', () {
    test('transitions client to awaitingAccount status', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});

      await handlers.handleBan(client);

      expect(client.status, ClientStatus.awaitingAccount);
    });

    test('calls updateCharacterBanned with correct characterId', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});

      await handlers.handleBan(client);

      verify(() => mockAccountRepo.updateCharacterBanned(10, true)).called(1);
    });

    test('creates banDetected notification with character name', () async {
      final client = makeClient(
        name: 'BannedChar',
        status: ClientStatus.banned,
        characterId: 10,
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});

      await handlers.handleBan(client);

      verify(() => mockNotificationService.createNotification(
            type: NotificationType.banDetected,
            severity: NotificationSeverity.error,
            title: 'Ban Detected',
            message: 'BannedChar banned after 3 consecutive quick deaths.',
          )).called(1);
    });

    test('rotates proxy when proxySlotId is set', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        proxySlotId: 5,
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockAutoRotation.rotateSlot(5)).thenAnswer((_) async => true);

      // Mock _buildProxyUrl dependencies
      final now = DateTime.now();
      when(() => mockProxyRepo.getSlotById(5))
          .thenAnswer((_) async => ProxySlotEntity(
                id: 5,
                slotName: 'Slot 5',
                slotNumber: 5,
                username: 'user5',
                password: 'pass5',
                port: 80,
                socksPort: 1080,
                createdAt: now,
                lastUpdated: now,
                totalIpChanges: 0,
                isActive: true,
              ));
      when(() => mockProxyRepo.getActiveIpForSlot(5))
          .thenAnswer((_) async => ProxyIpAddressEntity(
                id: 50,
                ipAddress: '9.8.7.6',
                hostname: '9.8.7.6',
                slotId: 5,
                isActive: true,
                countryCode: 'US',
                cityName: 'NYC',
                ipTimezone: 'UTC',
                highCountryConfidence: true,
                asnName: 'ASN',
                asnNumber: 1,
                ipScore: 10,
                scoreLevel: IpScoreLevel.excellent,
                isVpn: false,
                isProxy: true,
                isDatacenter: false,
                isTor: false,
                fraudScore: 10,
                assignedAt: now,
                lastVerification: now,
                totalDaysUsed: 1,
                timesAssigned: 1,
              ));

      await handlers.handleBan(client);

      verify(() => mockAutoRotation.rotateSlot(5)).called(1);
      expect(client.proxyUrl, 'socks5://user5:pass5@9.8.7.6:1080');
    });

    test('does not rotate proxy when proxySlotId is null', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        proxySlotId: null,
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});

      await handlers.handleBan(client);

      verifyNever(() => mockAutoRotation.rotateSlot(any()));
    });

    test('does not update proxyUrl when rotation fails', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        proxySlotId: 5,
        proxyUrl: 'socks5://old:proxy@1.1.1.1:1080',
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockAutoRotation.rotateSlot(5)).thenAnswer((_) async => false);

      await handlers.handleBan(client);

      // proxyUrl should remain unchanged when rotation fails
      expect(client.proxyUrl, 'socks5://old:proxy@1.1.1.1:1080');
    });

    test('does not update proxyUrl when buildProxyUrl returns null', () async {
      final client = makeClient(
        status: ClientStatus.banned,
        characterId: 10,
        proxySlotId: 5,
        proxyUrl: 'socks5://old:proxy@1.1.1.1:1080',
        consecutiveQuickDeaths: 3,
      );

      when(() => mockAccountRepo.updateCharacterBanned(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockAutoRotation.rotateSlot(5)).thenAnswer((_) async => true);

      // Slot has no socksPort => _buildProxyUrl returns null
      final now = DateTime.now();
      when(() => mockProxyRepo.getSlotById(5))
          .thenAnswer((_) async => ProxySlotEntity(
                id: 5,
                slotName: 'Slot 5',
                slotNumber: 5,
                username: 'user5',
                password: 'pass5',
                port: 80,
                socksPort: null,
                createdAt: now,
                lastUpdated: now,
                totalIpChanges: 0,
                isActive: true,
              ));

      await handlers.handleBan(client);

      // proxyUrl should remain unchanged when buildProxyUrl returns null
      expect(client.proxyUrl, 'socks5://old:proxy@1.1.1.1:1080');
    });
  });
}
