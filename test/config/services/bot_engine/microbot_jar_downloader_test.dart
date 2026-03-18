// test/config/services/bot_engine/microbot_jar_downloader_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';

void main() {
  group('MicrobotJarDownloader', () {
    test('findShadedJarUrl finds correct asset from release JSON', () {
      final assets = [
        {'name': 'microbot-1.0.0.jar', 'url': 'https://api.github.com/repos/test/releases/assets/1'},
        {'name': 'microbot-1.0.0-shaded.jar', 'url': 'https://api.github.com/repos/test/releases/assets/2'},
        {'name': 'source.zip', 'url': 'https://api.github.com/repos/test/releases/assets/3'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, 'https://api.github.com/repos/test/releases/assets/2');
    });

    test('findShadedJarUrl returns null when no shaded JAR', () {
      final assets = [
        {'name': 'source.zip', 'url': 'https://api.github.com/repos/test/releases/assets/3'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, isNull);
    });

    test('isUpdateAvailable compares versions', () {
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.0.0', remote: 'v1.1.0'), isTrue);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.1.0', remote: 'v1.1.0'), isFalse);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: null, remote: 'v1.0.0'), isTrue);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.0.0', remote: null), isFalse);
    });
  });
}
