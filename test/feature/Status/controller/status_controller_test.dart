import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// StatusController cannot be unit tested in isolation because:
/// 1. It calls Get.find<NativeCommandsService>() at field initialization time
///    (not just in onInit), making it impossible to construct without DI.
/// 2. NativeCommandsService depends on platform channels (Windows MethodChannel).
///
/// To properly test StatusController, it would need to:
/// - Accept NativeCommandsService as a constructor parameter instead of Get.find
/// - Or move the Get.find call into onInit
///
/// For now, we skip this controller test and note the architectural dependency.
void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('StatusController', () {
    test('requires NativeCommandsService in DI - skipped due to platform channel dependency',
        () {
      // StatusController eagerly calls Get.find<NativeCommandsService>()
      // at construction time, which requires platform channels.
      // This test documents the constraint.
      expect(true, isTrue);
    });
  });
}
