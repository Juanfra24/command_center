import 'dart:io';
import 'package:path/path.dart' as p;

class MicrobotProfileWriter {
  final String profilesBasePath;

  MicrobotProfileWriter({required this.profilesBasePath});

  String profilePath({required int characterId}) {
    return p.join(profilesBasePath, 'bot-$characterId');
  }

  Future<void> writeProfile({
    required int characterId,
    required String email,
    required String password,
    required String world,
    required String scriptName,
    String scriptParams = '',
  }) async {
    final dir = Directory(profilePath(characterId: characterId));
    await dir.create(recursive: true);

    final settings = StringBuffer();
    if (world != 'auto' && world.isNotEmpty) {
      settings.writeln('world=$world');
    }
    settings.writeln('script=$scriptName');
    if (scriptParams.isNotEmpty) {
      settings.writeln('scriptParams=$scriptParams');
    }
    await File(p.join(dir.path, 'commandcenter.properties'))
        .writeAsString(settings.toString());

    final credentials = StringBuffer();
    credentials.writeln('email=$email');
    credentials.writeln('password=$password');
    await File(p.join(dir.path, 'credentials.properties'))
        .writeAsString(credentials.toString());
  }

  Future<void> deleteProfile({required int characterId}) async {
    final dir = Directory(profilePath(characterId: characterId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> cleanStaleProfiles({required Set<int> liveCharacterIds}) async {
    final baseDir = Directory(profilesBasePath);
    if (!await baseDir.exists()) return;

    await for (final entity in baseDir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (name.startsWith('bot-')) {
          final idStr = name.substring(4);
          final id = int.tryParse(idStr);
          if (id != null && !liveCharacterIds.contains(id)) {
            await entity.delete(recursive: true);
          }
        }
      }
    }
  }
}
