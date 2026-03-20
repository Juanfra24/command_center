import 'package:command_center/config/services/setup/setup_orchestrator.dart';
import 'package:command_center/config/services/setup/setup_step_state.dart';
import 'package:command_center/feature/app/views/components/setup_step_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Setup wizard splash screen shown during app initialization.
/// Displays all 4 setup steps as a vertical list with real-time progress.
class SplashScreen extends StatefulWidget {
  final SetupOrchestrator? orchestrator;

  const SplashScreen({super.key, this.orchestrator});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final orchestrator = widget.orchestrator;

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
        child: SizedBox(
          width: 420,
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
              const SizedBox(height: 8),
              Text(
                'Setting up...',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
              const SizedBox(height: 32),
              if (orchestrator != null) ...[
                Obx(() {
                  final stepList = orchestrator.steps;
                  return Column(
                    children: [
                      for (var i = 0; i < stepList.length; i++)
                        SetupStepTile(state: stepList[i]),
                    ],
                  );
                }),
                // Input field (shown when a step needs user input, e.g. GitHub PAT)
                Obx(() {
                  final currentIdx = orchestrator.currentStepIndex.value;
                  final currentStep = orchestrator.steps[currentIdx];
                  if (!currentStep.needsInput) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentStep.inputLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              currentStep.inputLabel!,
                              style: theme.typography.caption,
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: PasswordBox(
                                controller: _inputController,
                                placeholder: 'ghp_...',
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                final value = _inputController.text.trim();
                                if (value.isNotEmpty) {
                                  orchestrator.submitInput(value);
                                  _inputController.clear();
                                }
                              },
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Step counter
                Obx(() {
                  final total = orchestrator.steps.length;
                  return Text(
                    'Step ${orchestrator.currentStepIndex.value + 1} of $total',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  );
                }),
                // Retry button (visible when a step fails)
                Obx(() {
                  final currentIdx = orchestrator.currentStepIndex.value;
                  final currentStep = orchestrator.steps[currentIdx];
                  if (currentStep.status != StepStatus.failed) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton(
                      onPressed: () => orchestrator.retryCurrentStep(),
                      child: const Text('Retry'),
                    ),
                  );
                }),
              ] else ...[
                const ProgressRing(),
                const SizedBox(height: 12),
                Text(
                  'Initializing...',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
