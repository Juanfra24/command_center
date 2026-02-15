import 'dart:io';

import 'package:command_center/config/services/ipqs_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare_service.dart';
import 'package:command_center/config/theme/fluent_app_theme.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/core/resource/dependency_injection.dart';
import 'package:command_center/core/widgets/window_title_bar.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/views/status_screen.dart';
import 'package:command_center/feature/main_menu/views/main_menu_screen.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/views/proxy_screen.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
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

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
                _buildMusicButton(),
                const SizedBox(width: 8),
                _buildThemeToggle(isDark),
              ],
            ),
            // Main content
            Expanded(
              child: _initialized
                  ? _buildMainContent(isDark)
                  : _buildLoadingScreen(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProgressRing(),
          SizedBox(height: 16),
          Text('Loading...'),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    return Obx(() {
      // Check onboarding status
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
          toggleable: false, // Disable built-in toggle since we have our own in title bar
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
          ],
        ),
      );
    });
  }

  Widget _buildHomeWithOnboarding(
      bool needsOnboarding, OnboardingService? onboardingService) {
    if (needsOnboarding) {
      return _buildOnboardingRequired(onboardingService);
    }
    return const MainMenuScreen();
  }

  Widget _buildAccountsWithOnboarding(bool needsOnboarding) {
    // Always show StatusScreen - it handles its own empty state
    return const StatusScreen();
  }

  Widget _buildOnboardingRequired(OnboardingService? onboardingService) {
    return Builder(
      builder: (context) {
        final theme = FluentTheme.of(context);

        return ScaffoldPage(
          header: const PageHeader(title: Text('Welcome')),
          content: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        FluentIcons.rocket,
                        size: 40,
                        color: theme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Get Started',
                      style: theme.typography.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connect your Webshare account to sync proxy slots and start managing your bots.',
                      style: theme.typography.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildSetupChecklist(onboardingService),
                    const SizedBox(height: 16),
                    Text(
                      'Click the step above to begin setup',
                      style: theme.typography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupChecklist(OnboardingService? onboardingService) {
    final isWebshareComplete = onboardingService?.isWebshareConfigured.value ?? false;
    final isIpqsComplete = onboardingService?.isIpqsConfigured.value ?? false;

    return Builder(
      builder: (context) => Column(
        children: [
          _buildChecklistItem(
            context,
            'Connect Webshare & Sync Proxies',
            'Connect your proxy provider and import slots',
            isWebshareComplete,
            onTap: () => _showWebshareConfigDialog(context),
          ),
          const SizedBox(height: 12),
          _buildChecklistItem(
            context,
            'Configure IPQualityScore',
            'Enable IP scoring and fraud detection',
            isIpqsComplete,
            isEnabled: isWebshareComplete,
            onTap: () => _showIpqsOnboardingDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
      BuildContext context, String title, String subtitle, bool isComplete,
      {VoidCallback? onTap, bool isEnabled = true}) {
    final theme = FluentTheme.of(context);
    final isClickable = !isComplete && isEnabled;

    return GestureDetector(
      onTap: isClickable ? onTap : null,
      child: MouseRegion(
        cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? Colors.green.withValues(alpha: 0.1)
                  : theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isComplete
                    ? Colors.green.withValues(alpha: 0.5)
                    : theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete ? FluentIcons.check_mark : FluentIcons.circle_ring,
                  color: isComplete ? Colors.green : (isEnabled ? theme.accentColor : Colors.grey),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.typography.bodyStrong?.copyWith(
                          decoration:
                              isComplete ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(subtitle, style: theme.typography.caption),
                    ],
                  ),
                ),
                if (isClickable)
                  Icon(
                    FluentIcons.chevron_right,
                    size: 14,
                    color: theme.accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMusicButton() {
    try {
      final musicController = Get.find<MusicController>();
      return Obx(() => IconButton(
            icon: Icon(
              musicController.isPlaying.value
                  ? FluentIcons.music_in_collection_fill
                  : FluentIcons.music_note,
            ),
            onPressed: () {
              if (musicController.isPlaying.value) {
                musicController.pauseAudio();
              } else {
                musicController.playAudio();
              }
            },
          ));
    } catch (e) {
      return const SizedBox.shrink();
    }
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

  Widget _buildMusicVolumeControl(BuildContext context) {
    try {
      final musicController = Get.find<MusicController>();
      return Obx(() => Row(
            children: [
              Icon(
                musicController.volume.value == 0
                    ? FluentIcons.volume0
                    : musicController.volume.value < 0.5
                        ? FluentIcons.volume1
                        : FluentIcons.volume3,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: musicController.volume.value * 100,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    musicController.setVolume(value / 100);
                  },
                  label: '${(musicController.volume.value * 100).round()}%',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${(musicController.volume.value * 100).round()}%',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ),
            ],
          ));
    } catch (e) {
      return const Text('Music controller not available');
    }
  }

  Widget _buildSettingsPage(bool isDark, BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Settings')),
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance',
                  style: FluentTheme.of(context).typography.bodyLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Theme Mode'),
                  const Spacer(),
                  ToggleSwitch(
                    checked: isDark,
                    onChanged: (value) {
                      ThemeManage.changeThemeMode();
                    },
                    content: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Music Settings Card
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.music_note,
                      color: FluentTheme.of(context).accentColor),
                  const SizedBox(width: 8),
                  Text('Music',
                      style: FluentTheme.of(context).typography.bodyLarge),
                ],
              ),
              const SizedBox(height: 16),
              _buildMusicVolumeControl(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Integrations Card - Critical for onboarding
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.plug_connected,
                      color: FluentTheme.of(context).accentColor),
                  const SizedBox(width: 8),
                  Text('Integrations',
                      style: FluentTheme.of(context).typography.bodyLarge),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Webshare Integration
              _buildWebshareIntegrationTile(context),
              const SizedBox(height: 12),
              // IPQualityScore Integration
              _buildIpqsIntegrationTile(context),
              const SizedBox(height: 12),
              // WhatsApp Integration - Coming Soon
              // TODO: Implement WhatsApp notification integration
              _buildIntegrationTile(
                context,
                icon: FluentIcons.message,
                title: 'WhatsApp',
                description: 'Receive notifications via WhatsApp',
                isComingSoon: true,
                onConfigure: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About',
                  style: FluentTheme.of(context).typography.bodyLarge),
              const SizedBox(height: 16),
              const Text('RuneScape Bot Command Center'),
              const Text('Version 0.4.0'),
              const SizedBox(height: 8),
              const Text(
                'Your go-to app for managing and orchestrating your automated tasks with ease.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebshareIntegrationTile(BuildContext context) {
    return Obx(() {
      bool isConfigured = false;

      try {
        final webshareService = Get.find<WebshareService>();
        isConfigured = webshareService.isConfigured.value;
      } catch (_) {}

      return _buildIntegrationTile(
        context,
        icon: FluentIcons.globe,
        title: 'Webshare',
        description: 'Proxy service integration for IP management',
        isConfigured: isConfigured,
        onConfigure: () => _showWebshareConfigDialog(context),
      );
    });
  }

  Widget _buildIpqsIntegrationTile(BuildContext context) {
    return Obx(() {
      bool isConfigured = false;

      try {
        final ipqsService = Get.find<IpqsService>();
        isConfigured = ipqsService.isConfigured.value;
      } catch (_) {}

      return _buildIntegrationTile(
        context,
        icon: FluentIcons.shield,
        title: 'IPQualityScore',
        description: 'IP scoring and fraud detection service',
        isConfigured: isConfigured,
        onConfigure: () => _showIpqsConfigDialog(context),
      );
    });
  }

  Widget _buildIntegrationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    bool isConfigured = false,
    bool isComingSoon = false,
    VoidCallback? onConfigure,
  }) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConfigured
              ? Colors.green.withValues(alpha: 0.5)
              : theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComingSoon
                  ? Colors.grey.withValues(alpha: 0.2)
                  : theme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isComingSoon ? Colors.grey : theme.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: theme.typography.bodyStrong),
                    if (isComingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Coming Soon',
                          style: TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    ],
                    if (isConfigured) ...[
                      const SizedBox(width: 8),
                      Icon(FluentIcons.check_mark,
                          size: 14, color: Colors.green),
                    ],
                  ],
                ),
                Text(description, style: theme.typography.caption),
              ],
            ),
          ),
          if (!isComingSoon)
            Button(
              onPressed: onConfigure,
              child: Text(isConfigured ? 'Edit' : 'Configure'),
            ),
        ],
      ),
    );
  }

  void _showWebshareConfigDialog(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;

    // Check if already configured
    bool isConfigured = false;
    try {
      final webshareService = Get.find<WebshareService>();
      isConfigured = webshareService.isConfigured.value;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(
            isConfigured ? 'Webshare Configuration' : 'Configure Webshare'),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isConfigured) ...[
                  // Show configured state
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(FluentIcons.check_mark,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Webshare Connected'),
                              Text('Your proxy slots are synced',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To use a different API key, unlink the current configuration first.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ] else ...[
                  // Show configuration form
                  const Text(
                      'Enter your Webshare API key to sync your proxy slots.'),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'API Key',
                    child: TextBox(
                      controller: apiKeyController,
                      placeholder: 'Enter your Webshare API key',
                      obscureText: true,
                      enabled: !isProcessing.value,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can find your API key in your Webshare dashboard under API settings.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (statusMessage.value != null) ...[
                  const SizedBox(height: 16),
                  InfoBar(
                    title: Text(isError.value ? 'Error' : 'Status'),
                    content: Text(statusMessage.value!),
                    severity: isError.value
                        ? InfoBarSeverity.error
                        : InfoBarSeverity.info,
                  ),
                ],
              ],
            )),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (isConfigured) ...[
            // Unlink button for configured state
            Obx(() => Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Colors.red.withValues(alpha: 0.1)),
                  ),
                  onPressed: isProcessing.value
                      ? null
                      : () async {
                          isProcessing.value = true;
                          statusMessage.value = 'Unlinking...';
                          isError.value = false;

                          try {
                            final webshareService = Get.find<WebshareService>();
                            final success = await webshareService.clearApiKey();

                            if (success) {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();

                                displayInfoBar(
                                  context,
                                  builder: (ctx, close) {
                                    return InfoBar(
                                      title: const Text('Unlinked'),
                                      content: const Text(
                                          'Webshare has been disconnected.'),
                                      severity: InfoBarSeverity.warning,
                                      action: IconButton(
                                        icon: const Icon(FluentIcons.clear),
                                        onPressed: close,
                                      ),
                                    );
                                  },
                                );
                              }
                            } else {
                              statusMessage.value = 'Failed to unlink';
                              isError.value = true;
                            }
                          } catch (e) {
                            statusMessage.value = 'Error: $e';
                            isError.value = true;
                          } finally {
                            isProcessing.value = false;
                          }
                        },
                  child: isProcessing.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.plug_disconnected, size: 14),
                            SizedBox(width: 8),
                            Text('Unlink'),
                          ],
                        ),
                )),
          ] else ...[
            // Connect & Sync button for new configuration
            Obx(() => FilledButton(
                  onPressed: isProcessing.value
                      ? null
                      : () async {
                          if (apiKeyController.text.isEmpty) {
                            statusMessage.value = 'Please enter an API key';
                            isError.value = true;
                            return;
                          }

                          isProcessing.value = true;
                          statusMessage.value = 'Testing connection...';
                          isError.value = false;

                          try {
                            final webshareService = Get.find<WebshareService>();

                            // Test connection first
                            final testResult = await webshareService
                                .testAndConnect(apiKeyController.text);

                            if (!testResult.success) {
                              statusMessage.value =
                                  testResult.error ?? 'Connection failed';
                              isError.value = true;
                              isProcessing.value = false;
                              return;
                            }

                            // Save API key
                            statusMessage.value = 'Saving configuration...';
                            final saved = await webshareService
                                .saveApiKey(apiKeyController.text);

                            if (!saved) {
                              statusMessage.value = 'Failed to save API key';
                              isError.value = true;
                              isProcessing.value = false;
                              return;
                            }

                            // Sync proxies
                            statusMessage.value = 'Syncing proxy slots...';
                            try {
                              final proxyController =
                                  Get.find<ProxyController>();
                              await proxyController.syncWithWebshare();
                            } catch (e) {
                              // Non-fatal - continue anyway
                            }

                            // Mark onboarding complete
                            try {
                              final onboardingService =
                                  Get.find<OnboardingService>();
                              await onboardingService.markInitialSyncComplete();
                            } catch (_) {}

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            // Show InfoBar after dialog is closed using post-frame callback
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                displayInfoBar(
                                  context,
                                  builder: (ctx, close) {
                                    return InfoBar(
                                      title: const Text('Success'),
                                      content: const Text(
                                          'Webshare connected and proxies synced!'),
                                      severity: InfoBarSeverity.success,
                                      action: IconButton(
                                        icon: const Icon(FluentIcons.clear),
                                        onPressed: close,
                                      ),
                                    );
                                  },
                                );
                              }
                            });
                          } catch (e) {
                            statusMessage.value = 'Error: $e';
                            isError.value = true;
                          } finally {
                            isProcessing.value = false;
                          }
                        },
                  child: isProcessing.value
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: ProgressRing(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Processing...'),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.sync, size: 14),
                            SizedBox(width: 8),
                            Text('Connect & Sync'),
                          ],
                        ),
                )),
          ],
        ],
      ),
    );
  }

  void _showIpqsConfigDialog(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;

    // Check if already configured
    bool isConfigured = false;
    try {
      final ipqsService = Get.find<IpqsService>();
      isConfigured = ipqsService.isConfigured.value;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(
            isConfigured ? 'IPQualityScore Configuration' : 'Configure IPQualityScore'),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isConfigured) ...[
                  // Show configured state
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(FluentIcons.check_mark,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('IPQualityScore Connected'),
                              Text('IP scoring is active',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To use a different API key, unlink the current configuration first.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ] else ...[
                  // Show configuration form
                  const Text(
                      'Enter your IPQualityScore API key to enable IP scoring.'),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'API Key',
                    child: TextBox(
                      controller: apiKeyController,
                      placeholder: 'Enter your IPQualityScore API key',
                      obscureText: true,
                      enabled: !isProcessing.value,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get your API key from ipqualityscore.com',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (statusMessage.value != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isError.value
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        if (isProcessing.value)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          Icon(
                            isError.value
                                ? FluentIcons.error_badge
                                : FluentIcons.info,
                            size: 14,
                            color: isError.value ? Colors.red : Colors.blue,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusMessage.value!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isError.value ? Colors.red : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (isConfigured) ...[
            // Unlink button for configured state
            Obx(() => Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Colors.red.withValues(alpha: 0.1)),
                  ),
                  onPressed: isProcessing.value
                      ? null
                      : () async {
                          isProcessing.value = true;
                          statusMessage.value = 'Unlinking...';
                          isError.value = false;

                          try {
                            final ipqsService = Get.find<IpqsService>();
                            final success = await ipqsService.clearApiKey();

                            if (success) {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  displayInfoBar(
                                    context,
                                    builder: (ctx, close) {
                                      return InfoBar(
                                        title: const Text('Unlinked'),
                                        content: const Text(
                                            'IPQualityScore has been disconnected.'),
                                        severity: InfoBarSeverity.warning,
                                        action: IconButton(
                                          icon: const Icon(FluentIcons.clear),
                                          onPressed: close,
                                        ),
                                      );
                                    },
                                  );
                                }
                              });
                            } else {
                              statusMessage.value = 'Failed to unlink';
                              isError.value = true;
                            }
                          } catch (e) {
                            statusMessage.value = 'Error: $e';
                            isError.value = true;
                          } finally {
                            isProcessing.value = false;
                          }
                        },
                  child: isProcessing.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.plug_disconnected, size: 14),
                            SizedBox(width: 8),
                            Text('Unlink'),
                          ],
                        ),
                )),
          ] else ...[
            // Connect button for new configuration
            Obx(() => FilledButton(
                  onPressed: isProcessing.value
                      ? null
                      : () async {
                          if (apiKeyController.text.isEmpty) {
                            statusMessage.value = 'Please enter an API key';
                            isError.value = true;
                            return;
                          }

                          isProcessing.value = true;
                          statusMessage.value = 'Testing connection...';
                          isError.value = false;

                          try {
                            final ipqsService = Get.find<IpqsService>();

                            // Test connection first
                            final testResult = await ipqsService
                                .testAndConnect(apiKeyController.text);

                            if (!testResult.success) {
                              statusMessage.value =
                                  testResult.error ?? 'Connection failed';
                              isError.value = true;
                              isProcessing.value = false;
                              return;
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                displayInfoBar(
                                  context,
                                  builder: (ctx, close) {
                                    return InfoBar(
                                      title: const Text('Success'),
                                      content: const Text(
                                          'IPQualityScore connected!'),
                                      severity: InfoBarSeverity.success,
                                      action: IconButton(
                                        icon: const Icon(FluentIcons.clear),
                                        onPressed: close,
                                      ),
                                    );
                                  },
                                );
                              }
                            });
                          } catch (e) {
                            statusMessage.value = 'Error: $e';
                            isError.value = true;
                          } finally {
                            isProcessing.value = false;
                          }
                        },
                  child: isProcessing.value
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: ProgressRing(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Processing...'),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.plug_connected, size: 14),
                            SizedBox(width: 8),
                            Text('Connect'),
                          ],
                        ),
                )),
          ],
        ],
      ),
    );
  }

  /// IPQS onboarding dialog - connects and runs initial score of all IPs
  void _showIpqsOnboardingDialog(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Configure IPQualityScore'),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Enter your IPQualityScore API key to enable IP scoring and fraud detection.'),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'API Key',
                  child: TextBox(
                    controller: apiKeyController,
                    placeholder: 'Enter your IPQualityScore API key',
                    obscureText: true,
                    enabled: !isProcessing.value,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get your free API key from ipqualityscore.com (1,000 free lookups/month)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (statusMessage.value != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isError.value
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        if (isProcessing.value)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        else
                          Icon(
                            isError.value
                                ? FluentIcons.error_badge
                                : FluentIcons.info,
                            size: 14,
                            color: isError.value ? Colors.red : Colors.blue,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusMessage.value!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isError.value ? Colors.red : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )),
        actions: [
          Button(
            onPressed: isProcessing.value ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          Obx(() => FilledButton(
                onPressed: isProcessing.value
                    ? null
                    : () async {
                        if (apiKeyController.text.isEmpty) {
                          statusMessage.value = 'Please enter an API key';
                          isError.value = true;
                          return;
                        }

                        isProcessing.value = true;
                        statusMessage.value = 'Testing connection...';
                        isError.value = false;

                        try {
                          final ipqsService = Get.find<IpqsService>();

                          // Test connection
                          final testResult = await ipqsService
                              .testAndConnect(apiKeyController.text);

                          if (!testResult.success) {
                            statusMessage.value =
                                testResult.error ?? 'Connection failed';
                            isError.value = true;
                            isProcessing.value = false;
                            return;
                          }

                          // Score all IPs
                          statusMessage.value = 'Scoring all proxy IPs...';
                          try {
                            final proxyController = Get.find<ProxyController>();
                            final scored = await proxyController.scoreAllCurrentIps();
                            statusMessage.value = 'Scored $scored IPs successfully!';
                          } catch (e) {
                            // Non-fatal - continue anyway
                          }

                          // Mark onboarding complete
                          try {
                            final onboardingService = Get.find<OnboardingService>();
                            await onboardingService.markInitialSyncComplete();
                          } catch (_) {}

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              displayInfoBar(
                                context,
                                builder: (ctx, close) {
                                  return InfoBar(
                                    title: const Text('Setup Complete'),
                                    content: const Text(
                                        'IPQualityScore connected and all IPs scored!'),
                                    severity: InfoBarSeverity.success,
                                    action: IconButton(
                                      icon: const Icon(FluentIcons.clear),
                                      onPressed: close,
                                    ),
                                  );
                                },
                              );
                            }
                          });
                        } catch (e) {
                          statusMessage.value = 'Error: $e';
                          isError.value = true;
                        } finally {
                          isProcessing.value = false;
                        }
                      },
                child: isProcessing.value
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: ProgressRing(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Processing...'),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.shield, size: 14),
                          SizedBox(width: 8),
                          Text('Connect & Score All'),
                        ],
                      ),
              )),
        ],
      ),
    );
  }

  @override
  void onWindowClose() async {
    // Properly close all resources and processes
    try {
      // Stop any running bots/processes
      try {
        final statusController = Get.find<StatusController>();
        // Kill all running processes
        for (final process in statusController.processClients.values) {
          try {
            Process.killPid(process.processId);
          } catch (_) {}
        }
      } catch (_) {}

      // Clean up controllers
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
