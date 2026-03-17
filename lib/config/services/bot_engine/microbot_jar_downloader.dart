// lib/config/services/bot_engine/microbot_jar_downloader.dart
import 'dart:convert';
import 'dart:io';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:path/path.dart' as p;

/// Downloads and updates Microbot shaded JAR from GitHub Releases.
class MicrobotJarDownloader {
  final AppConfigService _appConfig;
  final String _basePath;

  static const _releasesUrl =
      'https://api.github.com/repos/Juanfra24/Microbot_Frieren/releases/latest';

  MicrobotJarDownloader({
    required AppConfigService appConfig,
    required String basePath,
  })  : _appConfig = appConfig,
        _basePath = basePath;

  /// Check for and download the latest Microbot JAR.
  /// Returns the path to the JAR, or null if download failed and no cached JAR exists.
  Future<String?> ensureJar({
    void Function(int downloaded, int total)? onProgress,
  }) async {
    final microbotDir = p.join(_basePath, 'microbot');
    await Directory(microbotDir).create(recursive: true);

    final existingPath = await _appConfig.getMicrobotJarPath();
    final existingVersion = await _appConfig.getMicrobotJarVersion();

    // Check for updates (gracefully handle rate limiting)
    String? remoteVersion;
    String? downloadUrl;
    try {
      final release = await _fetchLatestRelease();
      remoteVersion = release['tag_name'] as String?;
      final assets = (release['assets'] as List?)?.cast<Map<String, dynamic>>();
      downloadUrl = assets != null ? findShadedJarUrl(assets) : null;
    } catch (e) {
      logger.w('GitHub API check failed (rate limited?): $e');
      // Fall back to cached JAR if available
      if (existingPath != null && File(existingPath).existsSync()) {
        return existingPath;
      }
      return null;
    }

    // Skip download if up to date
    if (!isUpdateAvailable(local: existingVersion, remote: remoteVersion) &&
        existingPath != null &&
        File(existingPath).existsSync()) {
      return existingPath;
    }

    if (downloadUrl == null) {
      logger.w('No shaded JAR asset found in latest release');
      return existingPath;
    }

    logger.i('Downloading Microbot $remoteVersion...');

    // Download the JAR
    final jarPath = p.join(microbotDir, 'microbot-shaded.jar');
    final token = await _appConfig.getGithubPat();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      // Private repo assets require Bearer token + octet-stream accept
      if (token != null && token.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('Accept', 'application/octet-stream');
      }
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'JAR download failed with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var downloadedBytes = 0;

      final file = File(jarPath).openWrite();
      try {
        await for (final chunk in response) {
          file.add(chunk);
          downloadedBytes += chunk.length;
          onProgress?.call(downloadedBytes, totalBytes);
        }
      } finally {
        await file.close();
      }
    } catch (e) {
      logger.e('Failed to download Microbot JAR: $e');
      // Clean up partial download on failure
      final partial = File(jarPath);
      if (partial.existsSync()) await partial.delete();
      return existingPath;
    } finally {
      client.close();
    }

    // Store path and version
    await _appConfig.saveMicrobotJarPath(jarPath);
    if (remoteVersion != null) {
      await _appConfig.saveMicrobotJarVersion(remoteVersion);
    }

    logger.i('Microbot JAR saved to: $jarPath');
    return jarPath;
  }

  Future<Map<String, dynamic>> _fetchLatestRelease() async {
    final token = await _appConfig.getGithubPat();
    if (token == null || token.isEmpty) {
      throw Exception('GitHub PAT not configured — cannot access private repo');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(_releasesUrl));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('Authorization', 'Bearer $token');
      final response = await request.close();

      if (response.statusCode == 401) {
        throw Exception('GitHub PAT invalid or expired');
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw Exception('GitHub API rate limited');
      }
      if (response.statusCode == 404) {
        throw Exception('Release not found — check repo URL and PAT permissions');
      }

      final body = await response.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Find the *-shaded.jar asset URL from release assets list.
  static String? findShadedJarUrl(List<Map<String, dynamic>> assets) {
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('-shaded.jar')) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Compare local vs remote version tags (simple string comparison).
  static bool isUpdateAvailable({
    required String? local,
    required String? remote,
  }) {
    if (local == null) return true;
    if (remote == null) return false;
    return local != remote;
  }
}
