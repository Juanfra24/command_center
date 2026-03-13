import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/main_menu/views/sections/characters_status_section.dart';
import 'package:command_center/feature/main_menu/views/sections/recent_activity_section.dart';
import 'package:command_center/feature/main_menu/views/sections/system_overview_section.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class MainMenuScreen extends GetView<MainMenuController> {
  final void Function(int index)? onNavigateToIndex;

  const MainMenuScreen({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Overview')),
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.view_dashboard, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text('System Overview', style: theme.typography.subtitle),
                ],
              ),
              const SizedBox(height: 20),
              SystemOverviewSection(onNavigateToIndex: onNavigateToIndex),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.people, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text('Characters Status', style: theme.typography.subtitle),
                ],
              ),
              const SizedBox(height: 16),
              const CharactersStatusSection(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.history, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text('Recent Activity', style: theme.typography.subtitle),
                ],
              ),
              const SizedBox(height: 16),
              const RecentActivitySection(),
            ],
          ),
        ),
      ],
    );
  }
}
