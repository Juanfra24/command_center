// lib/config/services/bot_engine/java_installer.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:path/path.dart' as p;

/// Downloads and manages Eclipse Temurin JRE 17 for Microbot.
class JavaInstaller {
  final AppConfigService _appConfig;
  final String _basePath;

  JavaInstaller({required AppConfigService appConfig, required String basePath})
      : _appConfig = appConfig,
        _basePath = basePath;

  static const adoptiumDownloadUrl =
      'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse';

  /// Check if Java 17+ is available (either configured path or system).
  Future<String?> findJavaPath() async {
    // 1. Check configured path
    final configured = await _appConfig.getMicrobotJavaPath();
    if (configured != null && await _verifyJava(configured)) return configured;

    // 2. Check system java
    if (await _verifyJava('java')) return 'java';

    return null;
  }

  /// Download and install Eclipse Temurin JRE 17.
  /// [onProgress] called with (bytesDownloaded, totalBytes) for UI updates.
  Future<String> install({void Function(int downloaded, int total)? onProgress}) async {
    final javaDir = p.join(_basePath, 'java');
    await Directory(javaDir).create(recursive: true);

    final zipPath = p.join(javaDir, 'temurin-jre-17.zip');

    developer.log('Downloading Java 17 JRE from Adoptium...', name: 'JavaInstaller');

    // Download
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(adoptiumDownloadUrl));
      final response = await request.close();

      // Follow redirects are handled automatically by HttpClient
      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(zipPath).openWrite();
      await for (final chunk in response) {
        file.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, totalBytes);
      }
      await file.close();
    } finally {
      client.close();
    }

    developer.log('Extracting Java JRE...', name: 'JavaInstaller');

    // Extract zip using PowerShell (Windows)
    final extractResult = await Process.run('powershell', [
      '-Command',
      'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force',
    ]);

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract Java JRE: ${extractResult.stderr}');
    }

    // Find the extracted JRE directory (e.g., jdk-17.0.9+9-jre)
    final jreDir = await Directory(javaDir)
        .list()
        .where((e) => e is Directory && p.basename(e.path).startsWith('jdk-'))
        .first;

    final javaExePath = p.join(jreDir.path, 'bin', 'java.exe');

    // Store path in config
    await _appConfig.saveMicrobotJavaPath(javaExePath);

    // Clean up zip
    await File(zipPath).delete();

    developer.log('Java 17 installed at: $javaExePath', name: 'JavaInstaller');
    return javaExePath;
  }

  Future<bool> _verifyJava(String javaPath) async {
    try {
      final result = await Process.run(javaPath, ['--version']);
      final output = '${result.stdout}\n${result.stderr}';
      final version = parseJavaMajorVersion(output);
      return isJava17OrHigher(version);
    } catch (_) {
      return false;
    }
  }

  /// Parse Java major version from `java --version` output.
  static int? parseJavaMajorVersion(String output) {
    // Matches: openjdk 17.0.9, java version "1.8.0_301", etc.
    final modernMatch = RegExp(r'(?:openjdk|java)\s+(\d+)').firstMatch(output);
    if (modernMatch != null) return int.tryParse(modernMatch.group(1)!);

    // Legacy format: "1.8.0_301" → major version 8
    final legacyMatch = RegExp(r'"1\.(\d+)\.').firstMatch(output);
    if (legacyMatch != null) return int.tryParse(legacyMatch.group(1)!);

    return null;
  }

  static bool isJava17OrHigher(int? version) => version != null && version >= 17;
}
