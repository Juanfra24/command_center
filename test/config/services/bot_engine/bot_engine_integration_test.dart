// test/config/services/bot_engine/bot_engine_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:command_center/config/services/watchdog/tracked_client.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  group('Bot Engine Integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bot_engine_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('profile writer creates correct files for launch', () async {
      final writer = MicrobotProfileWriter(profilesBasePath: tempDir.path);

      await writer.writeProfile(
        characterId: 42,
        email: 'player@test.com',
        password: 'secret',
        world: '301',
        scriptName: 'Woodcutter',
      );

      // Verify credentials file
      final creds = File(p.join(tempDir.path, 'bot-42', 'credentials.properties'));
      expect(creds.existsSync(), isTrue);
      final credsContent = creds.readAsStringSync();
      expect(credsContent, contains('email=player@test.com'));
      expect(credsContent, contains('password=secret'));

      // Verify settings file
      final settings = File(p.join(tempDir.path, 'bot-42', 'settings.properties'));
      expect(settings.existsSync(), isTrue);
      final settingsContent = settings.readAsStringSync();
      expect(settingsContent, contains('world=301'));
      expect(settingsContent, contains('script=Woodcutter'));
    });

    test('ProxyUrlBuilder + TrackedClient round-trip', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user',
        password: 'pass',
        ipAddress: '1.2.3.4',
        socksPort: 1080,
      );

      final client = TrackedClient(
        characterName: 'TestBot',
        characterId: 42,
        accountId: 1,
        email: 'test@test.com',
        password: 'pass',
        proxyUrl: url,
        launchConfig: const LaunchConfig(scriptName: 'Test'),
        pid: 12345,
        launchedAt: DateTime.now(),
      );

      expect(client.proxyUrl, 'socks5://user:pass@1.2.3.4:1080');
      expect(client.email, 'test@test.com');
      expect(client.password, 'pass');
    });

    test('MicrobotEngine buildLaunchArgs produces correct command structure', () {
      final engine = MicrobotEngine(
        javaPath: '/java/bin/java.exe',
        jarPath: '/app/microbot-shaded.jar',
        profilesBasePath: tempDir.path,
        nativeCommands: NativeCommandsService(),
        onLog: (_) {},
      );

      final args = engine.buildLaunchArgs(
        characterId: 42,
        proxyUrl: 'socks5://user:pass@1.2.3.4:1080',
        config: const LaunchConfig(
          scriptName: 'Woodcutter',
          jvmArgs: '-Xmx384m -XX:+UseG1GC',
          advancedFlags: '-fps 15',
        ),
      );

      // JVM flags come first (before -jar)
      final jarIndex = args.indexOf('-jar');
      expect(jarIndex, greaterThan(0));
      expect(args.sublist(0, jarIndex), contains('-Xmx384m'));
      expect(args.sublist(0, jarIndex), contains('-XX:+UseG1GC'));

      // App flags come after jar path
      expect(args[jarIndex + 1], '/app/microbot-shaded.jar');
      final appFlags = args.sublist(jarIndex + 2);
      expect(appFlags, contains('--profile=bot-42'));
      expect(appFlags, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
      expect(appFlags, contains('--safe-mode'));
      expect(appFlags, contains('-fps'));
      expect(appFlags, contains('15'));
    });
  });
}
