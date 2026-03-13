import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IpqsOnboardingDialog {
  IpqsOnboardingDialog._();

  static void show(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final isCancelled = false.obs;
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
                  _buildStatusBar(
                    statusMessage: statusMessage,
                    isError: isError,
                    isProcessing: isProcessing,
                  ),
                ],
              ],
            )),
        actions: [
          Obx(() => Button(
                onPressed: isProcessing.value
                    ? () {
                        isCancelled.value = true;
                        statusMessage.value = 'Cancelling...';
                      }
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(isProcessing.value ? 'Cancel Scoring' : 'Cancel'),
              )),
          _buildConnectButton(
            context: context,
            dialogContext: dialogContext,
            apiKeyController: apiKeyController,
            isProcessing: isProcessing,
            isCancelled: isCancelled,
            statusMessage: statusMessage,
            isError: isError,
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusBar({
    required Rxn<String> statusMessage,
    required RxBool isError,
    required RxBool isProcessing,
  }) {
    return Obx(() => Container(
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
                  isError.value ? FluentIcons.error_badge : FluentIcons.info,
                  size: 14,
                  color: isError.value ? Colors.red : Colors.blue,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage.value ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: isError.value ? Colors.red : null,
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  static Widget _buildConnectButton({
    required BuildContext context,
    required BuildContext dialogContext,
    required TextEditingController apiKeyController,
    required RxBool isProcessing,
    required RxBool isCancelled,
    required Rxn<String> statusMessage,
    required RxBool isError,
  }) {
    return Obx(() => FilledButton(
          onPressed: isProcessing.value
              ? null
              : () async {
                  if (apiKeyController.text.isEmpty) {
                    statusMessage.value = 'Please enter an API key';
                    isError.value = true;
                    return;
                  }

                  isProcessing.value = true;
                  isCancelled.value = false;
                  statusMessage.value = 'Testing connection...';
                  isError.value = false;

                  try {
                    final ipqsService = Get.find<IpqsService>();

                    final testResult =
                        await ipqsService.testAndConnect(apiKeyController.text);

                    if (!testResult.success) {
                      statusMessage.value =
                          testResult.error ?? 'Connection failed';
                      isError.value = true;
                      isProcessing.value = false;
                      return;
                    }

                    if (!isCancelled.value) {
                      statusMessage.value = 'Scoring all proxy IPs...';
                      try {
                        final scoringController =
                            Get.find<ProxyScoringController>();
                        final scored =
                            await scoringController.scoreAllCurrentIps();
                        statusMessage.value =
                            'Scored $scored IPs successfully!';
                      } catch (e) {
                        // Non-fatal
                      }
                    }

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
                              content: Text(isCancelled.value
                                  ? 'IPQualityScore connected! Scoring was cancelled.'
                                  : 'IPQualityScore connected and all IPs scored!'),
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
        ));
  }
}
