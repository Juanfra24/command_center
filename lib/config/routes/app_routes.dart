import 'package:command_center/core/resource/widgets/menu_bar/menu_bar.dart';
import 'package:command_center/feature/Status/views/status_screen.dart';
import 'package:command_center/feature/main_menu/views/main_menu_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/resource/widgets/no_internet.dart';
import 'app_pages.dart';

abstract class AppPages {
  static final pages = [
    GetPage(
      name: Routes.initial,
      page: () => const MenuWrapper(
        child: MainmenuScreen(),
      ),
    ),
    GetPage(
      name: Routes.noInternet,
      page: () => const MenuWrapper(
        child: NoInternet(),
      ),
    ),
    GetPage(
      name: Routes.status,
      page: () => const MenuWrapper(
        child: StatusScreen(),
      ),
    ),
  ];
}

class MenuWrapper extends StatelessWidget {
  final Widget child;

  const MenuWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MenuBar(
      child: child,
    );
  }
}
