// test/config/services/bot_engine/microbot_jar_downloader_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';

void main() {
  group('MicrobotJarDownloader', () {
    test('findShadedJarAsset finds correct asset from release JSON', () {
      final assets = [
        {'name': 'microbot-1.0.0.jar', 'browser_download_url': 'https://example.com/normal.jar'},
        {'name': 'microbot-1.0.0-shaded.jar', 'browser_download_url': 'https://example.com/shaded.jar'},
        {'name': 'source.zip', 'browser_download_url': 'https://example.com/source.zip'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, 'https://example.com/shaded.jar');
    });

    test('findShadedJarAsset returns null when no shaded JAR', () {
      final assets = [
        {'name': 'source.zip', 'browser_download_url': 'https://example.com/source.zip'},
      ];

      final result = MicrobotJarDownloader.findShadedJarUrl(assets);
      expect(result, isNull);
    });

    test('isUpdateAvailable compares versions', () {
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.0.0', remote: 'v1.1.0'), isTrue);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: 'v1.1.0', remote: 'v1.1.0'), isFalse);
      expect(MicrobotJarDownloader.isUpdateAvailable(local: null, remote: 'v1.0.0'), isTrue);
    });
  });
}
