import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_profile_writer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late MicrobotProfileWriter writer;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('microbot_test_');
    writer = MicrobotProfileWriter(profilesBasePath: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MicrobotProfileWriter', () {
    test('writeProfile creates profile directory with settings and credentials', () async {
      await writer.writeProfile(
        characterId: 42,
        email: 'test@example.com',
        password: 'secret123',
        world: '301',
        scriptName: 'Tutorial Journey',
      );

      final profileDir = Directory(p.join(tempDir.path, 'bot-42'));
      expect(profileDir.existsSync(), isTrue);

      final settings = File(p.join(profileDir.path, 'commandcenter.properties'));
      expect(settings.existsSync(), isTrue);
      final settingsContent = settings.readAsStringSync();
      expect(settingsContent, contains('world=301'));

      final credentials = File(p.join(profileDir.path, 'credentials.properties'));
      expect(credentials.existsSync(), isTrue);
      final credentialsContent = credentials.readAsStringSync();
      expect(credentialsContent, contains('email=test@example.com'));
      expect(credentialsContent, contains('password=secret123'));
    });

    test('writeProfile handles auto world', () async {
      await writer.writeProfile(characterId: 7, email: 'auto@test.com', password: 'pass', world: 'auto', scriptName: 'Woodcutter');

      final settings = File(p.join(tempDir.path, 'bot-7', 'commandcenter.properties'));
      final content = settings.readAsStringSync();
      expect(content, isNot(contains('world=auto')));
    });

    test('deleteProfile removes the entire profile directory', () async {
      await writer.writeProfile(characterId: 42, email: 'test@example.com', password: 'pass', world: '301', scriptName: 'Test');
      final profileDir = Directory(p.join(tempDir.path, 'bot-42'));
      expect(profileDir.existsSync(), isTrue);
      await writer.deleteProfile(characterId: 42);
      expect(profileDir.existsSync(), isFalse);
    });

    test('deleteProfile is a no-op if profile does not exist', () async {
      await writer.deleteProfile(characterId: 999);
    });

    test('cleanStaleProfiles removes directories not in livePids', () async {
      await writer.writeProfile(characterId: 1, email: 'a@b.com', password: 'p', world: 'auto', scriptName: 'S');
      await writer.writeProfile(characterId: 2, email: 'c@d.com', password: 'p', world: 'auto', scriptName: 'S');
      await writer.cleanStaleProfiles(liveCharacterIds: {1});
      expect(Directory(p.join(tempDir.path, 'bot-1')).existsSync(), isTrue);
      expect(Directory(p.join(tempDir.path, 'bot-2')).existsSync(), isFalse);
    });

    test('profilePath returns correct directory path', () {
      expect(writer.profilePath(characterId: 42), p.join(tempDir.path, 'bot-42'));
    });
  });
}
