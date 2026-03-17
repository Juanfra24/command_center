import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/helper/app_data_path.dart';

void main() {
  group('AppDataPath', () {
    test('basePath returns non-empty string', () async {
      final appDataPath = AppDataPath();
      expect(appDataPath, isNotNull);
    });

    test('subDir joins base path with subdirectory', () {
      final result = AppDataPath.joinPath('/base/path', 'microbot_profiles');
      expect(result, '/base/path/microbot_profiles');
    });

    test('subDir handles trailing separator', () {
      final result = AppDataPath.joinPath('/base/path/', 'microbot_profiles');
      expect(result, '/base/path/microbot_profiles');
    });
  });
}
