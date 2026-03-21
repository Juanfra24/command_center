import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/app.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_storage/get_storage.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize file logging with rotation
  await initLogger();

  // Initialize system theme for Windows accent color
  await SystemTheme.accentColor.load();

  await windowManager.ensureInitialized();

  // Set window properties with Windows-style configuration
  await windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.setMinimumSize(const Size(1024, 700));
    await windowManager.setResizable(true);
    await windowManager.center();
    await windowManager.show();
    // Prevent the OS from immediately destroying the window on close so that
    // onWindowClose() can run async teardown before calling destroy().
    await windowManager.setPreventClose(true);
  });

  await GetStorage.init();

  runApp(const App());
}
