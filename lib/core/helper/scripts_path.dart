import 'dart:io';
import 'package:path/path.dart' as path;

/// Resolves the scripts directory path once and caches it.
/// Used by AutomationService and PythonSetupService.
String get scriptsPath => _cached ??= _resolve();

String? _cached;

String _resolve() {
  final execDir = path.dirname(Platform.resolvedExecutable);

  // In development, scripts are next to lib
  final devScriptsPath = path.join(
    path.dirname(path.dirname(execDir)),
    'scripts',
  );
  if (Directory(devScriptsPath).existsSync()) return devScriptsPath;

  // Try relative to workspace
  final workspacePath = path.join(
    Platform.environment['USERPROFILE'] ?? '',
    'projects',
    'command_center',
    'scripts',
  );
  if (Directory(workspacePath).existsSync()) return workspacePath;

  // Fallback to bundled scripts
  return path.join(execDir, 'data', 'scripts');
}
