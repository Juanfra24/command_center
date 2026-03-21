import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/feature/Status/views/status_screen.dart';
import 'package:command_center/feature/app/views/sections/onboarding_section.dart';
import 'package:command_center/feature/app/views/sections/settings_section.dart';
import 'package:command_center/feature/dev_tools/views/dev_tools_screen.dart';
import 'package:command_center/feature/main_menu/views/main_menu_screen.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:command_center/feature/proxy/views/proxy_screen.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Main navigation pane containing all page items and footer items.
class AppNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final PaneDisplayMode displayMode;
  final bool isDark;
  final VoidCallback onNavigateToSettings;
  final ValueChanged<int> onNavigateToIndex;
  final MusicController? musicController;
  final WebshareService? webshareService;
  final IpqsService? ipqsService;
  final AppConfigService? appConfigService;

  const AppNavigation({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    required this.displayMode,
    required this.isDark,
    required this.onNavigateToSettings,
    required this.onNavigateToIndex,
    this.musicController,
    this.webshareService,
    this.ipqsService,
    this.appConfigService,
  });

  @override
  Widget build(BuildContext context) {
    OnboardingService? onboardingService;
    bool needsOnboarding = false;

    try {
      onboardingService = Get.find<OnboardingService>();
      // needsOnboarding is read synchronously here, but AppNavigation is
      // always rebuilt when the parent _AppState calls setState(). The parent
      // installs ever() workers on OnboardingService's observables
      // (isWebshareConfigured, isIpqsConfigured, isInitialSyncComplete) via
      // AppLifecycle.setupOnboardingWorkers(), so any change to onboarding
      // state triggers a parent setState → this build() reruns with fresh
      // values. No Obx wrapper is needed here.
      needsOnboarding = !onboardingService.isOnboardingComplete;
    } catch (_) {
      // Service not ready yet
    }

    return NavigationView(
      appBar: const NavigationAppBar(
        height: 0, // Hide default app bar since we use custom title bar
        automaticallyImplyLeading: false,
      ),
      pane: NavigationPane(
        selected: currentIndex,
        onChanged: onChanged,
        displayMode: displayMode,
        toggleable:
            false, // Disable built-in toggle since we have our own in title bar
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Home'),
            body: _buildHome(needsOnboarding, onboardingService),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.server),
            title: const Text('Accounts'),
            body: const StatusScreen(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.globe),
            title: const Text('Proxies'),
            body: ProxyScreen(onNavigateToSettings: onNavigateToSettings),
          ),
        ],
        footerItems: [
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: Builder(
              builder: (context) => SettingsSection(
                isDark: isDark,
                musicController: musicController,
                webshareService: webshareService,
                ipqsService: ipqsService,
                appConfigService: appConfigService,
              ),
            ),
          ),
          if (kDebugMode)
            PaneItem(
              icon: const Icon(FluentIcons.code),
              title: const Text('Dev Tools'),
              body: const DevToolsScreen(),
            ),
        ],
      ),
    );
  }

  Widget _buildHome(
      bool needsOnboarding, OnboardingService? onboardingService) {
    if (needsOnboarding) {
      return OnboardingSection(onboardingService: onboardingService);
    }
    return MainMenuScreen(onNavigateToIndex: onNavigateToIndex);
  }
}
