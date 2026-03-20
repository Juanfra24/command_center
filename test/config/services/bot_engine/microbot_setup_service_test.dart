// test/config/services/bot_engine/microbot_setup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';

void main() {
  group('MicrobotSetupService', () {
    test('MicrobotSetupStep enum values exist', () {
      expect(MicrobotSetupStep.idle, isNotNull);
      expect(MicrobotSetupStep.python, isNotNull);
      expect(MicrobotSetupStep.java, isNotNull);
      expect(MicrobotSetupStep.microbot, isNotNull);
      expect(MicrobotSetupStep.complete, isNotNull);
      expect(MicrobotSetupStep.failed, isNotNull);
    });

    test('MicrobotSetupStep enum has correct ordering', () {
      expect(MicrobotSetupStep.values.indexOf(MicrobotSetupStep.python),
          lessThan(MicrobotSetupStep.values.indexOf(MicrobotSetupStep.java)));
      expect(
          MicrobotSetupStep.values.indexOf(MicrobotSetupStep.java),
          lessThan(
              MicrobotSetupStep.values.indexOf(MicrobotSetupStep.microbot)));
      expect(
          MicrobotSetupStep.values.indexOf(MicrobotSetupStep.microbot),
          lessThan(
              MicrobotSetupStep.values.indexOf(MicrobotSetupStep.complete)));
    });
  });
}
