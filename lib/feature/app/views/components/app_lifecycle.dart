import 'dart:ui';

import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/setup/setup_orchestrator.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/dependency_injection.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:get/get.dart';

/// Holds references to services resolved after DI initialization.
class ResolvedServices {
  final MusicController? musicController;
  final NotificationService? notificationService;
  final NotificationController? notificationController;
  final WebshareService? webshareService;
  final IpqsService? ipqsService;
  final AppConfigService? appConfigService;

  const ResolvedServices({
    this.musicController,
    this.notificationService,
    this.notificationController,
    this.webshareService,
    this.ipqsService,
    this.appConfigService,
  });
}

/// Initialization and teardown helpers extracted from the App shell.
class AppLifecycle {
  /// Runs full DI bootstrap: sync bindings, async services, setup, post-setup.
  static Future<void> initialize() async {
    AppBindings().dependencies();
    await AppBindings.initializeAsyncServices();

    if (Get.isRegistered<SetupOrchestrator>()) {
      await Get.find<SetupOrchestrator>().run();
    }

    await AppBindings.initializePostSetup();
  }

  /// Resolves all services from DI, logging failures without throwing.
  static ResolvedServices resolveServices() {
    return ResolvedServices(
      musicController: _tryFind<MusicController>(),
      notificationService: _tryFind<NotificationService>(),
      notificationController: _tryFind<NotificationController>(),
      webshareService: _tryFind<WebshareService>(),
      ipqsService: _tryFind<IpqsService>(),
      appConfigService: _tryFind<AppConfigService>(),
    );
  }

  /// Registers onboarding ever() workers that call [onComplete] when
  /// onboarding finishes.
  static List<Worker> setupOnboardingWorkers(VoidCallback onComplete) {
    final workers = <Worker>[];
    try {
      final obs = Get.find<OnboardingService>();
      void check(dynamic _) {
        if (obs.isOnboardingComplete) onComplete();
      }

      workers.add(ever(obs.isWebshareConfigured, check));
      workers.add(ever(obs.isIpqsConfigured, check));
      workers.add(ever(obs.isInitialSyncComplete, check));
    } catch (_) {}
    return workers;
  }

  /// Cleans up controllers and stops music on window close.
  static Future<void> teardown() async {
    try {
      await Get.delete<StatusController>(force: true);
    } catch (_) {}
    try {
      await Get.delete<ProxyController>(force: true);
    } catch (_) {}
    try {
      Get.find<MusicController>().stopAudio();
    } catch (_) {}
  }

  static T? _tryFind<T>() {
    try {
      return Get.find<T>();
    } catch (e) {
      logger.e('Failed to resolve ${T.toString()}: $e');
      return null;
    }
  }
}
