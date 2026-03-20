import 'dart:io';

/// Opens a file or directory in the platform's default file manager.
Future<void> openInFileManager(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer.exe', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}
