import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:command_center/config/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('resetOnboarding resets all observable flags to false', () async {
      final service = OnboardingService();

      // Manually set flags to true to simulate configured state
      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);

      await service.resetOnboarding();

      expect(service.isWebshareConfigured.value, isFalse);
      expect(service.isIpqsConfigured.value, isFalse);
      expect(service.isInitialSyncComplete.value, isFalse);
      expect(service.isOnboardingComplete, isFalse);
    });

    test('isOnboardingComplete requires all three flags', () {
      final service = OnboardingService();

      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isInitialSyncComplete.value = false;
      expect(service.isOnboardingComplete, isFalse);

      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);
    });
  });
}
