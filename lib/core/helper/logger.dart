import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Global logger instance.
///
/// Before [initLogger] is called, logs go to the console only.
/// After [initLogger], logs go to both the console and a rotating log file
/// at `<AppDocumentsDirectory>/logs/command_center.log`.
Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

/// Initializes file-based logging with rotation.
///
/// Writes to `<AppDocumentsDirectory>/logs/` using [AdvancedFileOutput]:
/// - Max 5 MB per file (rotates when exceeded)
/// - Keeps up to 3 rotated archive files
///
/// Call this early in `main()` after [WidgetsFlutterBinding.ensureInitialized].
Future<void> initLogger() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final logDir = Directory(p.join(docsDir.path, 'logs'));
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  final fileOutput = AdvancedFileOutput(
    path: logDir.path,
    maxFileSizeKB: 5 * 1024, // 5 MB
    maxRotatedFilesCount: 3,
    latestFileName: 'command_center.log',
  );

  logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
    output: MultiOutput([
      ConsoleOutput(),
      fileOutput,
    ]),
  );
}
