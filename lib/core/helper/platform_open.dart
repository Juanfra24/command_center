import 'dart:io';

import 'package:command_center/core/helper/logger.dart';

/// Opens a file or directory in the platform's default file manager.
/// Never throws — file-manager launch errors are logged and swallowed so
/// callers (usually UI buttons) don't have to wrap every tap handler.
Future<void> openInFileManager(String path) async {
  try {
    final exec = Platform.isWindows ? 'explorer.exe' : 'xdg-open';
    await Process.run(exec, [path])
        .timeout(const Duration(seconds: 5), onTimeout: () {
      logger.w('openInFileManager timed out for $path');
      return ProcessResult(0, -1, '', 'timeout');
    });
  } catch (e) {
    logger.e('openInFileManager failed for $path: $e');
  }
}
