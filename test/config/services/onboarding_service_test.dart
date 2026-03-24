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
      service.isImapConfigured.value = true;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isTrue);

      await service.resetOnboarding();

      expect(service.isWebshareConfigured.value, isFalse);
      expect(service.isIpqsConfigured.value, isFalse);
      expect(service.isImapConfigured.value, isFalse);
      expect(service.isInitialSyncComplete.value, isFalse);
      expect(service.isOnboardingComplete, isFalse);
    });

    test('isOnboardingComplete requires all four flags', () {
      final service = OnboardingService();

      service.isWebshareConfigured.value = true;
      service.isIpqsConfigured.value = true;
      service.isImapConfigured.value = false;
      service.isInitialSyncComplete.value = true;
      expect(service.isOnboardingComplete, isFalse);

      service.isImapConfigured.value = true;
      expect(service.isOnboardingComplete, isTrue);
    });
  });
}
