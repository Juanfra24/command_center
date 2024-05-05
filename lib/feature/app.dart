import 'package:command_center/config/routes/app_pages.dart';
import 'package:command_center/config/routes/app_routes.dart';
import 'package:command_center/config/theme/app_theme.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/core/resource/dependency_injection.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/main.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Frieren Bot Command Center',
      navigatorKey: globalNavKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeManage.getThemeMode(),
      initialBinding: AppBindings(),
      getPages: AppPages.pages,
      initialRoute: Routes.initial,
    );
  }

  @override
  void onWindowClose() async {
    await Get.delete<StatusController>();
  }
}
