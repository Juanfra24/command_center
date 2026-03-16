import 'package:command_center/config/services/bot_engine/microbot_setup_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Branded splash screen shown during app initialization and dependency setup.
class SplashScreen extends StatelessWidget {
  final MicrobotSetupService? setupService;

  const SplashScreen({super.key, this.setupService});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor.withOpacity(0.95),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Command Center',
              style: theme.typography.title?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 40),
            // Progress bar
            SizedBox(
              width: 300,
              child: setupService != null
                  ? Obx(() => ProgressBar(value: setupService!.progressPercent.value * 100))
                  : const ProgressBar(),
            ),
            const SizedBox(height: 12),
            // Status text
            if (setupService != null)
              Obx(() => Text(
                    setupService!.progress.value.isNotEmpty
                        ? setupService!.progress.value
                        : 'Initializing...',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ))
            else
              Text(
                'Loading...',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
