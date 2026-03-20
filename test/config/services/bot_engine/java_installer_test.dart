// test/config/services/bot_engine/java_installer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/java_installer.dart';

void main() {
  group('JavaInstaller', () {
    test('parseJavaMajorVersion parses modern and legacy version strings', () {
      // Java 17 version output: 'openjdk 17.0.9 2023-10-17'
      expect(
          JavaInstaller.parseJavaMajorVersion('openjdk 17.0.9 2023-10-17'), 17);
      expect(
          JavaInstaller.parseJavaMajorVersion('openjdk 21.0.1 2023-10-17'), 21);
      expect(
          JavaInstaller.parseJavaMajorVersion('java version "1.8.0_301"'), 8);
      expect(JavaInstaller.parseJavaMajorVersion('not java output'), null);
    });

    test('isJava17OrHigher returns correct result', () {
      expect(JavaInstaller.isJava17OrHigher(17), isTrue);
      expect(JavaInstaller.isJava17OrHigher(21), isTrue);
      expect(JavaInstaller.isJava17OrHigher(8), isFalse);
      expect(JavaInstaller.isJava17OrHigher(null), isFalse);
    });

    test('adoptiumUrl returns correct download URL', () {
      final url = JavaInstaller.adoptiumDownloadUrl;
      expect(url, contains('api.adoptium.net'));
      expect(url, contains('/17/'));
      expect(url, anyOf(contains('windows'), contains('linux')));
      expect(url, contains('jre'));
    });
  });
}
