import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/jagex/jagex_token_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('jagex_token_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('JagexTokenService._writeCredentialsFile', () {
    test('writes correct JX_* format to jagex/credentials.properties',
        () async {
      await JagexTokenService.writeCredentialsFile(
        profileDir: tempDir.path,
        sessionId: 'sess_abc',
        characterId: 'char_123',
        displayName: 'BotFrieren',
      );

      final file =
          File(p.join(tempDir.path, 'jagex', 'credentials.properties'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('JX_CHARACTER_ID=char_123'));
      expect(content, contains('JX_SESSION_ID=sess_abc'));
      expect(content, contains('JX_DISPLAY_NAME=BotFrieren'));
      expect(content, contains('JX_REFRESH_TOKEN='));
      expect(content, contains('JX_ACCESS_TOKEN='));
    });

    test('creates jagex/ subdirectory if it does not exist', () async {
      final subDir = p.join(tempDir.path, 'bot-99');
      await JagexTokenService.writeCredentialsFile(
        profileDir: subDir,
        sessionId: 's',
        characterId: 'c',
        displayName: 'd',
      );
      expect(Directory(p.join(subDir, 'jagex')).existsSync(), isTrue);
    });
  });

  group('JagexTokenService.jagexHomeDir', () {
    test('returns profileDir/jagex', () {
      expect(
        JagexTokenService.jagexHomeDir('/profiles/bot-42'),
        p.join('/profiles/bot-42', 'jagex'),
      );
    });
  });
}
