import 'package:command_center/config/services/setup/setup_orchestrator.dart';
import 'package:command_center/config/theme/fluent_app_theme.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/core/widgets/toast_overlay.dart';
import 'package:command_center/feature/app/views/components/app_lifecycle.dart';
import 'package:command_center/feature/app/views/components/app_navigation.dart';
import 'package:command_center/feature/app/views/components/app_title_bar.dart';
import 'package:command_center/feature/app/views/splash_screen.dart';
import 'package:fluent_ui/fluent_ui.dart';
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

  ResolvedServices _services = const ResolvedServices();
  final List<Worker> _onboardingWorkers = [];
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Phase 1: Register all services (including SetupOrchestrator)
      await AppLifecycle.initializeServices();

      // Trigger rebuild so splash screen can observe the orchestrator
      if (mounted) setState(() {});

      // Phase 2: Run setup (blocks until all 4 steps complete)
      await AppLifecycle.runSetup();

      // Phase 3: BotEngine + WatchdogService
      await AppLifecycle.finalizeSetup();

      _services = AppLifecycle.resolveServices();
      _onboardingWorkers.addAll(
        AppLifecycle.setupOnboardingWorkers(() {
          if (mounted) setState(() {});
        }),
      );

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _fatalError = 'Initialization failed: $e');
      }
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

  // Navigation indices: Home=0, Accounts=1, Proxies=2, [Separator], Settings=3, [DevTools=4 in debug]
  static const _settingsIndex = 3;

  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
  }

  void navigateToSettings() => _navigateToIndex(_settingsIndex);

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
            AppTitleBar(
              paneDisplayMode: _paneDisplayMode,
              onTogglePane: _togglePane,
              flyoutController: _flyoutController,
              musicController: _services.musicController,
              notificationService: _services.notificationService,
              notificationController: _services.notificationController,
              isDark: isDark,
            ),
            Expanded(
              child: _initialized
                  ? ToastOverlay(
                      child: AppNavigation(
                        currentIndex: _currentIndex,
                        onChanged: _navigateToIndex,
                        displayMode: _paneDisplayMode,
                        isDark: isDark,
                        onNavigateToSettings: navigateToSettings,
                        onNavigateToIndex: _navigateToIndex,
                        musicController: _services.musicController,
                        webshareService: _services.webshareService,
                        ipqsService: _services.ipqsService,
                        appConfigService: _services.appConfigService,
                        imapConfigService: _services.imapConfigService,
                      ),
                    )
                  : _buildSplashScreen(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSplashScreen() {
    if (_fatalError != null) {
      return SplashScreen(fatalError: _fatalError);
    }
    final orchestrator = Get.isRegistered<SetupOrchestrator>()
        ? Get.find<SetupOrchestrator>()
        : null;
    return SplashScreen(orchestrator: orchestrator);
  }

  @override
  void onWindowClose() async {
    await AppLifecycle.teardown();
    await windowManager.destroy();
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}
}
