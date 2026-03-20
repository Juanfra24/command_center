import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';
import 'package:path/path.dart' as p;
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockNativeCommands extends Mock implements NativeCommandsService {}

MicrobotEngine _makeEngine({
  String jarPath = '/app/microbot-shaded.jar',
  String profilesBasePath = '/profiles',
}) {
  return MicrobotEngine(
    javaPath: '/java/bin/java.exe',
    jarPath: jarPath,
    profilesBasePath: profilesBasePath,
    nativeCommands: _MockNativeCommands(),
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
      final expectedProfileDir = p.join('/profiles', 'bot-42');
      expect(args[0], '-Xmx384m');
      expect(args[1], '-jar');
      expect(args[2], '/app/microbot-shaded.jar');
      expect(args, contains('--cc-profile-dir=$expectedProfileDir'));
      expect(
          args,
          contains(
              '--status-port-file=${p.join(expectedProfileDir, 'status.port')}'));
      expect(args, contains('--proxy=socks5://user:pass@1.2.3.4:1080'));
      expect(args, contains('--safe-mode'));
    });

    test('buildLaunchArgs omits --proxy when proxyUrl is null', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
          characterId: 7,
          proxyUrl: null,
          config: const LaunchConfig(scriptName: 'Test'));
      expect(args.any((a) => a.startsWith('--proxy')), isFalse);
    });

    test('buildLaunchArgs uses default -Xmx512m when jvmArgs is null', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
          characterId: 1,
          proxyUrl: null,
          config: const LaunchConfig(scriptName: 'Test'));
      expect(args[0], '-Xmx512m');
    });

    test('buildLaunchArgs includes advancedFlags', () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
        characterId: 1,
        proxyUrl: null,
        config: const LaunchConfig(
            scriptName: 'Test', advancedFlags: '-fps 15 --low-detail'),
      );
      expect(args, contains('-fps'));
      expect(args, contains('15'));
      expect(args, contains('--low-detail'));
    });

    test(
        'buildLaunchArgs includes --script-params when scriptParams is non-empty',
        () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
        characterId: 1,
        proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test', scriptParams: '1,2,3'),
      );
      expect(args, contains('--script-params=1,2,3'));
    });

    test('buildLaunchArgs omits --script-params when scriptParams is empty',
        () {
      final engine = _makeEngine();
      final args = engine.buildLaunchArgs(
        characterId: 1,
        proxyUrl: null,
        config: const LaunchConfig(scriptName: 'Test', scriptParams: ''),
      );
      expect(args.any((a) => a.startsWith('--script-params')), isFalse);
    });

    test('registerRecapturedPid adds PID to activePids', () {
      final engine = _makeEngine();
      engine.registerRecapturedPid(pid: 1234, characterId: 42);
      expect(engine.activePids, contains(1234));
    });
  });
}
