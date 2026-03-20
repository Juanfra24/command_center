import 'dart:io';

import 'package:command_center/core/constants/app_version.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/scripts_path.dart' as sp;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Extracts bundled Python scripts from Flutter assets to the app data directory.
/// Re-extracts when the app version changes (detected via a .scripts_version marker).
class ScriptsExtractor {
  final String _appDataDir;

  ScriptsExtractor({required String appDataDir}) : _appDataDir = appDataDir;

  String get _scriptsDir => p.join(_appDataDir, 'scripts');
  String get _versionMarker => p.join(_scriptsDir, '.scripts_version');

  /// List of asset paths to extract (relative to project root).
  /// Only runtime files — excludes hooks/, release/, dev-only scripts.
  static const List<String> assetPaths = [
    'scripts/account_automation.py',
    'scripts/requirements.txt',
    'scripts/automation/__init__.py',
    'scripts/automation/browser.py',
    'scripts/automation/helpers.py',
    'scripts/automation/imap_poller.py',
    'scripts/automation/models.py',
    'scripts/automation/proxy.py',
    'scripts/automation/commands/__init__.py',
    'scripts/automation/commands/create_account.py',
    'scripts/automation/commands/session.py',
    'scripts/automation/commands/validate.py',
  ];

  /// Check if extraction is needed (first launch or version change).
  Future<bool> needsExtraction() async {
    final marker = File(_versionMarker);
    if (!await marker.exists()) return true;
    final storedVersion = (await marker.readAsString()).trim();
    return storedVersion != appVersion;
  }

  /// Extract all bundled scripts to the app data directory.
  /// Updates the scripts path helper after extraction.
  Future<void> extract({void Function(String detail)? onProgress}) async {
    logger.i('Extracting scripts to $_scriptsDir (version $appVersion)');

    // Create directory structure
    final dirs = [
      _scriptsDir,
      p.join(_scriptsDir, 'automation'),
      p.join(_scriptsDir, 'automation', 'commands'),
    ];
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }

    // Extract each asset
    for (final assetPath in assetPaths) {
      final fileName = p.basename(assetPath);
      onProgress?.call('Extracting $fileName...');

      try {
        final data = await rootBundle.loadString(assetPath);
        // Convert asset path (scripts/automation/browser.py) to local path
        final relativePath = assetPath.substring('scripts/'.length);
        final destPath = p.join(_scriptsDir, relativePath);
        await File(destPath).writeAsString(data);
      } catch (e) {
        logger.e('Failed to extract $assetPath: $e');
        rethrow;
      }
    }

    // Write version marker
    await File(_versionMarker).writeAsString(appVersion);

    // Update the global scripts path
    sp.setScriptsPath(_scriptsDir);
    logger.i('Scripts extracted successfully to $_scriptsDir');
  }
}
