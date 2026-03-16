import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/watchdog/launch_config.dart';

void main() {
  group('LaunchConfig', () {
    test('creates with required scriptName and defaults', () {
      const config = LaunchConfig(scriptName: 'Tutorial Journey');
      expect(config.scriptName, 'Tutorial Journey');
      expect(config.world, 'auto');
      expect(config.scriptParams, '');
      expect(config.advancedFlags, '');
      expect(config.jvmArgs, null);
    });

    test('creates with custom jvmArgs', () {
      const config = LaunchConfig(
        scriptName: 'Woodcutter',
        jvmArgs: '-Xmx384m',
      );
      expect(config.jvmArgs, '-Xmx384m');
    });

    test('does not have covert or render fields', () {
      const config = LaunchConfig(scriptName: 'Test');
      expect(config.scriptName, 'Test');
    });
  });
}
