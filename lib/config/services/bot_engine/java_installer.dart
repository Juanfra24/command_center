// lib/config/services/bot_engine/java_installer.dart
import 'dart:io';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:path/path.dart' as p;

/// Downloads and manages Eclipse Temurin JRE 17 for Microbot.
class JavaInstaller {
  final AppConfigService _appConfig;
  final String _basePath;

  JavaInstaller({required AppConfigService appConfig, required String basePath})
      : _appConfig = appConfig,
        _basePath = basePath;

  /// Adoptium architecture string for the current platform.
  static String get _arch {
    // Dart's Platform doesn't expose CPU arch directly, but we can check
    // the resolved executable path or use a process call.
    // On Linux, `uname -m` returns aarch64 or x86_64.
    // On Windows, x64 is the only supported Flutter desktop arch.
    if (Platform.isWindows) return 'x64';
    // For Linux, detect at runtime — _archCache is set by _detectArch()
    return _archCache ?? 'x64';
  }

  static String? _archCache;

  /// Detect the CPU architecture on Linux.
  static Future<void> detectArch() async {
    if (Platform.isWindows) return;
    try {
      final result = await Process.run('uname', ['-m']);
      final machine = (result.stdout as String).trim();
      _archCache = machine == 'aarch64' ? 'aarch64' : 'x64';
    } catch (_) {
      _archCache = 'x64';
    }
  }

  static String get adoptiumDownloadUrl => Platform.isWindows
      ? 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jre/hotspot/normal/eclipse'
      : 'https://api.adoptium.net/v3/binary/latest/17/ga/linux/$_arch/jre/hotspot/normal/eclipse';

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
  Future<String> install(
      {void Function(int downloaded, int total)? onProgress}) async {
    final javaDir = p.join(_basePath, 'java');
    await Directory(javaDir).create(recursive: true);

    final archiveExt = Platform.isWindows ? 'zip' : 'tar.gz';
    final zipPath = p.join(javaDir, 'temurin-jre-17.$archiveExt');

    logger.i('Downloading Java 17 JRE from Adoptium...');

    // Download
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(adoptiumDownloadUrl));
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw Exception(
            'Java download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(zipPath).openWrite();
      try {
        await for (final chunk in response) {
          file.add(chunk);
          downloadedBytes += chunk.length;
          onProgress?.call(downloadedBytes, totalBytes);
        }
      } finally {
        await file.close();
      }
    } finally {
      client.close();
    }

    logger.i('Extracting Java JRE...');

    // Extract archive (platform-specific)
    final ProcessResult extractResult;
    if (Platform.isWindows) {
      extractResult = await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$javaDir" -Force',
      ]);
    } else {
      extractResult = await Process.run('tar', [
        '-xzf',
        zipPath,
        '-C',
        javaDir,
      ]);
    }

    // Clean up zip regardless of extraction result
    try {
      await File(zipPath).delete();
    } catch (_) {}

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract Java JRE: ${extractResult.stderr}');
    }

    // Find the extracted JRE directory (e.g., jdk-17.0.9+9-jre)
    final jreDirs = await Directory(javaDir)
        .list()
        .where((e) => e is Directory && p.basename(e.path).startsWith('jdk-'))
        .toList();

    if (jreDirs.isEmpty) {
      throw Exception(
          'Java JRE extraction failed: no jdk-* directory found in $javaDir');
    }

    final javaExeName = Platform.isWindows ? 'java.exe' : 'java';
    final javaExePath = p.join(jreDirs.first.path, 'bin', javaExeName);
    if (!await File(javaExePath).exists()) {
      throw Exception(
          'Java JRE extraction incomplete: $javaExeName not found at $javaExePath');
    }

    // Store path in config
    await _appConfig.saveMicrobotJavaPath(javaExePath);

    logger.i('Java 17 installed at: $javaExePath');
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

  static bool isJava17OrHigher(int? version) =>
      version != null && version >= 17;
}
