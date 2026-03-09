// NOTE: This file is kept for backwards compatibility but navigation is now
// handled by the FluentApp NavigationView in app.dart
// The app now uses a single-page navigation pattern with NavigationPane

import 'package:command_center/feature/Status/views/status_screen.dart';
import 'package:command_center/feature/main_menu/views/main_menu_screen.dart';
import 'package:command_center/feature/proxy/views/proxy_screen.dart';
import 'package:get/get.dart';

import '../../core/resource/widgets/no_internet.dart';
import 'app_pages.dart';

abstract class AppPages {
  static final pages = [
    GetPage(
      name: Routes.initial,
      page: () => const MainMenuScreen(),
    ),
    GetPage(
      name: Routes.noInternet,
      page: () => const NoInternet(),
    ),
    GetPage(
      name: Routes.status,
      page: () => const StatusScreen(),
    ),
    GetPage(
      name: Routes.proxies,
      page: () => const ProxyScreen(),
    ),
  ];
}
