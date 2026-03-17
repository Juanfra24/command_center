import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';

MicrobotEngine _makeEngine({String jarPath = '/app/microbot-shaded.jar'}) {
  return MicrobotEngine(
    javaPath: '/java/bin/java.exe',
    jarPath: jarPath,
    profilesBasePath: '/profiles',
    nativeCommands: NativeCommandsService(),
    onLog: (_) {},
  );
}

void main() {
  group('MicrobotEngine', () {
    test('engineName returns Microbot', () {
      final engine = _makeEngine();
      expect(engine.engineName, 'Microbot');
    });

    test('buildLaunchArgs constructs correct argument list with proxy', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
        characterId: 42,
        proxyUrl: 'socks5://user:pass@1.2.3.4:1080',
        config: const LaunchConfig(scriptName: 'Tutorial', jvmArgs: '-Xmx384m'),
      );
      expect(args[0], '-Xmx384m');
      expect(args[1], '-jar');
      expect(args[2], '/app/microbot-shaded.jar');
      expect(args, contains('--profile=bot-42'));
      expect(args, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
      expect(args, contains('--safe-mode'));
    });

    test('buildLaunchArgs omits --proxy when proxyUrl is null', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(characterId: 7, proxyUrl: null, config: const LaunchConfig(scriptName: 'Test'));
      expect(args.any((a) => a.startsWith('--proxy')), isFalse);
    });

    test('buildLaunchArgs uses default -Xmx512m when jvmArgs is null', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(characterId: 1, proxyUrl: null, config: const LaunchConfig(scriptName: 'Test'));
      expect(args[0], '-Xmx512m');
    });

    test('buildLaunchArgs includes advancedFlags', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
        characterId: 1, proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test', advancedFlags: '-fps 15 --low-detail'),
      );
      expect(args, contains('-fps'));
      expect(args, contains('15'));
      expect(args, contains('--low-detail'));
    });
  });
}
