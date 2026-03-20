import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/setup/scripts_extractor.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ScriptsExtractor', () {
    late Directory tempDir;
    late ScriptsExtractor extractor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('scripts_test_');
      extractor = ScriptsExtractor(appDataDir: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('needsExtraction returns true when no marker exists', () async {
      expect(await extractor.needsExtraction(), isTrue);
    });

    test('needsExtraction returns false when marker matches version', () async {
      final scriptsDir = Directory(p.join(tempDir.path, 'scripts'));
      await scriptsDir.create(recursive: true);
      await File(p.join(scriptsDir.path, '.scripts_version'))
          .writeAsString('0.8.0');
      expect(await extractor.needsExtraction(), isFalse);
    });

    test('needsExtraction returns true when marker has different version',
        () async {
      final scriptsDir = Directory(p.join(tempDir.path, 'scripts'));
      await scriptsDir.create(recursive: true);
      await File(p.join(scriptsDir.path, '.scripts_version'))
          .writeAsString('0.7.0');
      expect(await extractor.needsExtraction(), isTrue);
    });

    test('assetPaths contains all expected runtime files', () {
      expect(ScriptsExtractor.assetPaths, contains('scripts/requirements.txt'));
      expect(ScriptsExtractor.assetPaths,
          contains('scripts/account_automation.py'));
      expect(ScriptsExtractor.assetPaths,
          contains('scripts/automation/browser.py'));
      expect(ScriptsExtractor.assetPaths,
          contains('scripts/automation/commands/create_account.py'));
      // Ensure dev-only files are NOT included
      expect(ScriptsExtractor.assetPaths.any((p) => p.contains('hooks/')),
          isFalse);
      expect(ScriptsExtractor.assetPaths.any((p) => p.contains('release/')),
          isFalse);
      expect(ScriptsExtractor.assetPaths.any((p) => p.contains('openChrome')),
          isFalse);
      expect(ScriptsExtractor.assetPaths.any((p) => p.contains('test_captcha')),
          isFalse);
    });
  });
}
