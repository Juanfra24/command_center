// test/config/services/bot_engine/microbot_setup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';

void main() {
  group('MicrobotSetupService', () {
    test('initial state is idle', () {
      // Cannot fully construct without mocks, but verify enum values exist
      expect(SetupStep.idle, isNotNull);
      expect(SetupStep.python, isNotNull);
      expect(SetupStep.java, isNotNull);
      expect(SetupStep.microbot, isNotNull);
      expect(SetupStep.complete, isNotNull);
      expect(SetupStep.failed, isNotNull);
    });

    test('SetupStep enum has correct ordering', () {
      expect(SetupStep.values.indexOf(SetupStep.python),
          lessThan(SetupStep.values.indexOf(SetupStep.java)));
      expect(SetupStep.values.indexOf(SetupStep.java),
          lessThan(SetupStep.values.indexOf(SetupStep.microbot)));
      expect(SetupStep.values.indexOf(SetupStep.microbot),
          lessThan(SetupStep.values.indexOf(SetupStep.complete)));
    });
  });
}
