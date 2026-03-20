import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';
import 'package:command_center/config/services/setup/scripts_extractor.dart';
import 'package:command_center/config/services/setup/setup_orchestrator.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/config/services/bot_engine/bot_engine.dart';
import 'package:command_center/config/services/bot_engine/microbot_engine.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'dart:io' show Platform;
import 'package:command_center/config/services/native_commands_linux.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/config/services/native_commands_windows.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/proxy/proxy_auto_rotation_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/app_data_path.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';
import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_replacement_controller.dart';
import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/dev_tools/controller/dev_tools_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  static bool _initialized = false;

  @override
  void dependencies() {
    if (_initialized) return;
    _initialized = true;

    // Synchronous services first
    Get.put<AppDataPath>(AppDataPath(), permanent: true);
    Get.put<MusicController>(MusicController(), permanent: true);
    Get.put<NativeCommandsService>(
      Platform.isWindows ? NativeCommandsWindows() : NativeCommandsLinux(),
      permanent: true,
    );

    // Feature controllers (lazy - created when needed)
    Get.lazyPut<MainMenuController>(() => MainMenuController(), fenix: true);
    Get.lazyPut<StatusController>(() => StatusController(), fenix: true);
    Get.lazyPut<StatusSelectionController>(() => StatusSelectionController(),
        fenix: true);
    Get.lazyPut<ProxyController>(() => ProxyController(), fenix: true);
    Get.lazyPut<ProxyScoringController>(
      () => ProxyScoringController(
        Get.find<DatabaseService>().proxyRepository,
        Get.find<IpqsService>(),
        Get.find<ProxyController>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ProxyReplacementController>(
      () => ProxyReplacementController(Get.find<ProxyController>()),
      fenix: true,
    );
    Get.lazyPut<NotificationController>(
      () => NotificationController(Get.find<NotificationService>()),
      fenix: true,
    );
    Get.lazyPut<ProxyReplacementService>(
      () => ProxyReplacementService(Get.find<WebshareService>()),
      fenix: true,
    );
    Get.lazyPut<ProxySyncService>(
      () => ProxySyncService(
        Get.find<DatabaseService>().proxyRepository,
        Get.find<WebshareService>(),
        Get.find<DatabaseService>().database,
      ),
      fenix: true,
    );
    Get.lazyPut<ProxyAutoRotationService>(
      () => ProxyAutoRotationService(
        replacementService: Get.find<ProxyReplacementService>(),
        webshareService: Get.find<WebshareService>(),
        ipqsService: Get.find<IpqsService>(),
        proxyRepository: Get.find<DatabaseService>().proxyRepository,
        syncService: Get.find<ProxySyncService>(),
        notificationService: Get.find<NotificationService>(),
        configService: Get.find<AppConfigService>(),
      ),
      fenix: true,
    );

    // Dev tools (debug only)
    if (kDebugMode) {
      Get.lazyPut<DevToolsController>(
        () => DevToolsController(Get.find<DatabaseService>().database),
        fenix: true,
      );
    }
  }

  /// Initialize async services in proper order
  static Future<void> initializeAsyncServices() async {
    // 1. DatabaseService first (no dependencies)
    final databaseService = await DatabaseService().init();
    Get.put<DatabaseService>(databaseService, permanent: true);

    // 2. AppConfigService (depends on DatabaseService)
    final appConfigService = await AppConfigService().init();
    Get.put<AppConfigService>(appConfigService, permanent: true);

    // 3. WebshareService (depends on AppConfigService)
    final webshareService = await WebshareService().init();
    Get.put<WebshareService>(webshareService, permanent: true);

    // 4. IpqsService (depends on DatabaseService)
    final ipqsService = await IpqsService().init();
    Get.put<IpqsService>(ipqsService, permanent: true);

    // 5. PythonSetupService (check and install Python dependencies)
    final pythonSetupService = PythonSetupService();
    Get.put<PythonSetupService>(pythonSetupService, permanent: true);

    // 6. AutomationService (depends on Python setup)
    Get.put<AutomationService>(AutomationService(), permanent: true);

    // 7. OnboardingService (depends on WebshareService, IpqsService)
    Get.put<OnboardingService>(OnboardingService(), permanent: true);

    // 8. NotificationService (depends on DatabaseService)
    final notificationService =
        NotificationService(databaseService.notificationRepository);
    await notificationService.init();
    Get.put<NotificationService>(notificationService, permanent: true);

    // 9. MicrobotSetupService (orchestrates dependency downloads)
    final appDataPath = Get.find<AppDataPath>();
    final basePath = await appDataPath.basePath;
    final javaInstaller =
        JavaInstaller(appConfig: appConfigService, basePath: basePath);
    final jarDownloader =
        MicrobotJarDownloader(appConfig: appConfigService, basePath: basePath);
    Get.put<MicrobotSetupService>(
      MicrobotSetupService(
        pythonSetup: pythonSetupService,
        javaInstaller: javaInstaller,
        jarDownloader: jarDownloader,
      ),
      permanent: true,
    );

    // Setup Orchestrator (depends on all setup services)
    final setupOrchestrator = SetupOrchestrator(
      scriptsExtractor: ScriptsExtractor(appDataDir: basePath),
      pythonSetup: pythonSetupService,
      javaInstaller: javaInstaller,
      jarDownloader: jarDownloader,
      appConfig: appConfigService,
    );
    Get.put<SetupOrchestrator>(setupOrchestrator, permanent: true);

    // NOTE: WatchdogService moved to initializePostSetup() — it depends on
    // BotEngine which requires SetupOrchestrator.run() to download dependencies first.
  }

  /// Phase 2b: Register BotEngine + WatchdogService.
  /// Called AFTER SetupOrchestrator.run() downloads Java/JAR.
  /// Skips BotEngine registration if setup failed (no Java/JAR paths).
  static Future<void> initializePostSetup() async {
    final appDataPath = Get.find<AppDataPath>();
    final basePath = await appDataPath.basePath;
    final appConfig = Get.find<AppConfigService>();
    final javaPath = await appConfig.getMicrobotJavaPath();
    final jarPath = await appConfig.getMicrobotJarPath();

    // Only create BotEngine if we have a valid Java path.
    // JAR can be null (user can still use the app without bot engine).
    if (javaPath == null) {
      logger.w('Skipping BotEngine setup — Java not available');
      return;
    }

    final microbotEngine = MicrobotEngine(
      javaPath: javaPath,
      jarPath: jarPath ?? '',
      profilesBasePath: AppDataPath.joinPath(basePath, 'microbot_profiles'),
      nativeCommands: Get.find<NativeCommandsService>(),
      onLog: (msg) => logger.i(msg),
    );
    Get.put<BotEngine>(microbotEngine, permanent: true);

    // WatchdogService (depends on BotEngine, NotificationService, DatabaseService)
    // Eager init triggers startup recapture scan via onInit().
    final databaseService = Get.find<DatabaseService>();
    Get.put<WatchdogService>(
      WatchdogService(
        nativeCommandsService: Get.find<NativeCommandsService>(),
        botEngine: Get.find<BotEngine>(),
        notificationService: Get.find<NotificationService>(),
        autoRotationService: Get.find<ProxyAutoRotationService>(),
        accountRepository: databaseService.accountRepository,
        proxyRepository: databaseService.proxyRepository,
      ),
      permanent: true,
    );
  }
}
