import 'package:command_center/config/services/bot_engine/java_installer.dart';
import 'package:command_center/config/services/bot_engine/microbot_jar_downloader.dart';
import 'package:command_center/config/services/python_setup_service.dart';
import 'package:get/get.dart';

/// Holds references to setup dependencies for DI wiring.
/// Setup orchestration is handled by SetupOrchestrator.
class MicrobotSetupService extends GetxService {
  final PythonSetupService pythonSetup;
  final JavaInstaller javaInstaller;
  final MicrobotJarDownloader jarDownloader;

  /// Setup is always required — SetupOrchestrator blocks until complete.
  bool get canProceed => true;

  MicrobotSetupService({
    required this.pythonSetup,
    required this.javaInstaller,
    required this.jarDownloader,
  });
}
