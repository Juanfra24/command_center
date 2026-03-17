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
            theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
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
              Obx(() {
                final step = setupService!.currentStep.value;
                final isFailed = step == MicrobotSetupStep.failed;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      setupService!.progress.value.isNotEmpty
                          ? setupService!.progress.value
                          : 'Initializing...',
                      style: theme.typography.caption?.copyWith(
                        color: isFailed ? Colors.red : theme.inactiveColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isFailed) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton(
                            onPressed: () => setupService!.retry(),
                            child: const Text('Retry'),
                          ),
                          const SizedBox(width: 8),
                          Button(
                            onPressed: () => setupService!.skip(),
                            child: const Text('Skip'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              })
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
