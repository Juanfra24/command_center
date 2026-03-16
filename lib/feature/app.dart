import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/app/views/splash_screen.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/feature/app/views/sections/onboarding_section.dart';
import 'package:command_center/feature/app/views/sections/settings_section.dart';
import 'package:command_center/config/theme/fluent_app_theme.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/core/resource/dependency_injection.dart';
import 'package:command_center/core/widgets/toast_overlay.dart';
import 'package:command_center/core/widgets/window_title_bar.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/views/status_screen.dart';
import 'package:command_center/feature/main_menu/views/main_menu_screen.dart';
import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/notification/views/components/notification_bell.dart';
import 'package:command_center/feature/dev_tools/views/dev_tools_screen.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/views/proxy_screen.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WindowListener {
  int _currentIndex = 0;
  bool _initialized = false;
  PaneDisplayMode _paneDisplayMode = PaneDisplayMode.open;
  final FlyoutController _flyoutController = FlyoutController();

  /// Resolved once after DI is ready — avoids Get.find() in every build call.
  MusicController? _musicController;
  NotificationService? _notificationService;
  NotificationController? _notificationController;
  WebshareService? _webshareService;
  IpqsService? _ipqsService;
  AppConfigService? _appConfigService;

  /// GetX ever() workers for onboarding service observables
  final List<Worker> _onboardingWorkers = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Ensure dependency injection is set up
    AppBindings().dependencies();

    // Initialize async services in proper order
    await AppBindings.initializeAsyncServices();

    // Setup dependencies (Java + Microbot JAR) — splash screen shows progress
    if (Get.isRegistered<MicrobotSetupService>()) {
      await Get.find<MicrobotSetupService>().ensureDependencies();
    }

    // Phase 2b: BotEngine + WatchdogService (depends on setup completing first)
    await AppBindings.initializePostSetup();

    // Resolve controllers once after services are ready
    try {
      _musicController = Get.find<MusicController>();
    } catch (e) {
      logger.e('Failed to resolve MusicController: $e');
    }
    try {
      _notificationService = Get.find<NotificationService>();
      _notificationController = Get.find<NotificationController>();
    } catch (e) {
      logger.e('Failed to resolve NotificationService/Controller: $e');
    }
    try {
      _webshareService = Get.find<WebshareService>();
    } catch (e) {
      logger.e('Failed to resolve WebshareService: $e');
    }
    try {
      _ipqsService = Get.find<IpqsService>();
    } catch (e) {
      logger.e('Failed to resolve IpqsService: $e');
    }
    try {
      _appConfigService = Get.find<AppConfigService>();
    } catch (e) {
      logger.e('Failed to resolve AppConfigService: $e');
    }

    // Optional: instant transition when onboarding completes without waiting
    // for a user-driven setState (e.g. navigation).
    try {
      final obs = Get.find<OnboardingService>();
      _onboardingWorkers.add(ever(obs.isWebshareConfigured, (_) {
        if (obs.isOnboardingComplete && mounted) setState(() {});
      }));
      _onboardingWorkers.add(ever(obs.isIpqsConfigured, (_) {
        if (obs.isOnboardingComplete && mounted) setState(() {});
      }));
      _onboardingWorkers.add(ever(obs.isInitialSyncComplete, (_) {
        if (obs.isOnboardingComplete && mounted) setState(() {});
      }));
    } catch (_) {}

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    for (final w in _onboardingWorkers) {
      w.dispose();
    }
    windowManager.removeListener(this);
    _flyoutController.dispose();
    super.dispose();
  }

  /// Navigate to a specific tab index
  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
  }

  /// Navigate directly to settings page
  void navigateToSettings() {
    _navigateToIndex(3); // Settings is at index 3 (after separator)
  }

  /// Toggle the navigation pane between open and compact modes
  void _togglePane() {
    setState(() {
      _paneDisplayMode = _paneDisplayMode == PaneDisplayMode.open
          ? PaneDisplayMode.compact
          : PaneDisplayMode.open;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeManage.currentThemeMode == ThemeMode.dark;

      return FluentApp(
        title: 'RuneScape Bot Command Center',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeManage.currentThemeMode,
        theme: FluentAppTheme.lightTheme(),
        darkTheme: FluentAppTheme.darkTheme(),
        home: Column(
          children: [
            // Custom title bar with window controls
            WindowTitleBar(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Menu toggle button
                  IconButton(
                    icon: Icon(
                      _paneDisplayMode == PaneDisplayMode.open
                          ? FluentIcons.collapse_menu
                          : FluentIcons.expand_menu,
                      size: 16,
                    ),
                    onPressed: _togglePane,
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/runescape_icon.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(FluentIcons.game, size: 20),
                  ),
                ],
              ),
              title: const Text('RuneScape Bot Command Center'),
              actions: [
                if (_notificationService != null &&
                    _notificationController != null)
                  NotificationBell(
                    flyoutController: _flyoutController,
                    notificationService: _notificationService!,
                    notificationController: _notificationController!,
                  ),
                const SizedBox(width: 8),
                _buildMusicButton(),
                const SizedBox(width: 8),
                _buildThemeToggle(isDark),
              ],
            ),
            // Main content
            Expanded(
              child: _initialized
                  ? ToastOverlay(child: _buildMainContent(isDark))
                  : _buildSplashScreen(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSplashScreen() {
    final setupService = Get.isRegistered<MicrobotSetupService>()
        ? Get.find<MicrobotSetupService>()
        : null;
    return SplashScreen(setupService: setupService);
  }

  Widget _buildMainContent(bool isDark) {
    // Direct read — no Obx wrapper around NavigationView.
    // Onboarding completes at most once per session; the ever() listeners
    // set up in _initializeApp call setState() for an instant transition.
    OnboardingService? onboardingService;
    bool needsOnboarding = false;

    try {
      onboardingService = Get.find<OnboardingService>();
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
        selected: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        displayMode: _paneDisplayMode,
        toggleable:
            false, // Disable built-in toggle since we have our own in title bar
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Home'),
            body:
                _buildHomeWithOnboarding(needsOnboarding, onboardingService),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.server),
            title: const Text('Accounts'),
            body: _buildAccountsWithOnboarding(needsOnboarding),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.globe),
            title: const Text('Proxies'),
            body: ProxyScreen(onNavigateToSettings: navigateToSettings),
          ),
        ],
        footerItems: [
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: Builder(
              builder: (context) => _buildSettingsPage(isDark, context),
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

  Widget _buildHomeWithOnboarding(
      bool needsOnboarding, OnboardingService? onboardingService) {
    if (needsOnboarding) {
      return _buildOnboardingRequired(onboardingService);
    }
    return MainMenuScreen(
      onNavigateToIndex: _navigateToIndex,
    );
  }

  Widget _buildAccountsWithOnboarding(bool needsOnboarding) {
    // Always show StatusScreen - it handles its own empty state
    return const StatusScreen();
  }

  Widget _buildOnboardingRequired(OnboardingService? onboardingService) {
    return OnboardingSection(onboardingService: onboardingService);
  }

  Widget _buildMusicButton() {
    final mc = _musicController;
    if (mc == null) return const SizedBox.shrink();
    return Obx(() => IconButton(
          icon: Icon(
            mc.isPlaying.value
                ? FluentIcons.music_in_collection_fill
                : FluentIcons.music_note,
          ),
          onPressed: () {
            if (mc.isPlaying.value) {
              mc.pauseAudio();
            } else {
              mc.playAudio();
            }
          },
        ));
  }

  Widget _buildThemeToggle(bool isDark) {
    return ToggleSwitch(
      checked: isDark,
      onChanged: (value) {
        ThemeManage.changeThemeMode();
      },
      content: Row(
        children: [
          Icon(isDark ? FluentIcons.clear_night : FluentIcons.sunny),
          const SizedBox(width: 8),
          Text(isDark ? 'Dark' : 'Light'),
        ],
      ),
    );
  }

  Widget _buildSettingsPage(bool isDark, BuildContext context) {
    return SettingsSection(
      isDark: isDark,
      musicController: _musicController,
      webshareService: _webshareService,
      ipqsService: _ipqsService,
      appConfigService: _appConfigService,
    );
  }

  @override
  void onWindowClose() async {
    // Clean up controllers — bots are left running for recapture on next launch
    try {
      try {
        await Get.delete<StatusController>(force: true);
      } catch (_) {}

      try {
        await Get.delete<ProxyController>(force: true);
      } catch (_) {}

      try {
        final musicController = Get.find<MusicController>();
        musicController.stopAudio();
      } catch (_) {}
    } catch (_) {}

    // Destroy window
    await windowManager.destroy();
  }

  @override
  void onWindowFocus() {
    // Optional: refresh data when window gains focus
  }

  @override
  void onWindowBlur() {
    // Optional: handle window losing focus
  }
}
