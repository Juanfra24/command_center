import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/main_menu/views/sections/bot_status_grid_section.dart';
import 'package:command_center/feature/main_menu/views/sections/proxy_health_overview_section.dart';
import 'package:command_center/feature/main_menu/views/sections/quick_actions_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class MainMenuScreen extends GetView<MainMenuController> {
  final Function(int)? onNavigateToIndex;

  const MainMenuScreen({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Command Center')),
      children: [
        BotStatusGridSection(
          onNavigateToAccounts: () => onNavigateToIndex?.call(1),
          onStartAll: controller.startAll,
          onStopAll: controller.stopAll,
        ),
        const SizedBox(height: 16),
        ProxyHealthOverviewSection(
          onNavigateToProxies: () => onNavigateToIndex?.call(2),
        ),
        const SizedBox(height: 16),
        QuickActionsSection(
          onNavigateToIndex: onNavigateToIndex,
        ),
      ],
    );
  }
}
