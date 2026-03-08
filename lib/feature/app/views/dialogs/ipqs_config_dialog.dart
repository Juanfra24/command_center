import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IpqsConfigDialog {
  IpqsConfigDialog._();

  static void show(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;

    bool isConfigured = false;
    try {
      final ipqsService = Get.find<IpqsService>();
      isConfigured = ipqsService.isConfigured.value;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(isConfigured
            ? 'IPQualityScore Configuration'
            : 'Configure IPQualityScore'),
        content: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isConfigured) ...[
                  _buildConfiguredState(),
                ] else ...[
                  _buildConfigForm(apiKeyController, isProcessing),
                ],
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
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (isConfigured) ...[
            _buildUnlinkButton(
              context: context,
              dialogContext: dialogContext,
              isProcessing: isProcessing,
              statusMessage: statusMessage,
              isError: isError,
            ),
          ] else ...[
            _buildConnectButton(
              context: context,
              dialogContext: dialogContext,
              apiKeyController: apiKeyController,
              isProcessing: isProcessing,
              statusMessage: statusMessage,
              isError: isError,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildConfiguredState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.check_mark, color: Colors.green, size: 20),
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
      ],
    );
  }

  static Widget _buildConfigForm(
    TextEditingController apiKeyController,
    RxBool isProcessing,
  ) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        ));
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
                  isError.value
                      ? FluentIcons.error_badge
                      : FluentIcons.info,
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

  static Widget _buildUnlinkButton({
    required BuildContext context,
    required BuildContext dialogContext,
    required RxBool isProcessing,
    required Rxn<String> statusMessage,
    required RxBool isError,
  }) {
    return Obx(() => Button(
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
        ));
  }

  static Widget _buildConnectButton({
    required BuildContext context,
    required BuildContext dialogContext,
    required TextEditingController apiKeyController,
    required RxBool isProcessing,
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
                  statusMessage.value = 'Testing connection...';
                  isError.value = false;

                  try {
                    final ipqsService = Get.find<IpqsService>();

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
        ));
  }
}
