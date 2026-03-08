import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/api_key_form_field.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
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
      isConfigured = Get.find<IpqsService>().isConfigured.value;
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
                if (isConfigured)
                  const ApiKeyConfiguredBanner(
                    title: 'IPQualityScore Connected',
                    subtitle: 'IP scoring is active',
                  )
                else
                  ApiKeyFormField(
                    controller: apiKeyController,
                    isProcessing: isProcessing,
                    description:
                        'Enter your IPQualityScore API key to enable IP scoring.',
                    hint: 'Get your API key from ipqualityscore.com',
                    placeholder: 'Enter your IPQualityScore API key',
                  ),
                ProcessingStatusBar(
                  statusMessage: statusMessage,
                  isError: isError,
                  isProcessing: isProcessing,
                ),
              ],
            )),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (isConfigured)
            UnlinkActionButton(
              isProcessing: isProcessing,
              onUnlink: () => _handleUnlink(
                  context, dialogContext, isProcessing, statusMessage, isError),
            )
          else
            ConnectActionButton(
              isProcessing: isProcessing,
              onConnect: () => _handleConnect(context, dialogContext,
                  apiKeyController, isProcessing, statusMessage, isError),
            ),
        ],
      ),
    );
  }

  static Future<void> _handleUnlink(
    BuildContext context,
    BuildContext dialogContext,
    RxBool isProcessing,
    Rxn<String> statusMessage,
    RxBool isError,
  ) async {
    isProcessing.value = true;
    statusMessage.value = 'Unlinking...';
    isError.value = false;
    try {
      final success = await Get.find<IpqsService>().clearApiKey();
      if (success) {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        showInfoBarToast(context,
            title: 'Unlinked',
            message: 'IPQualityScore has been disconnected.',
            severity: InfoBarSeverity.warning);
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
  }

  static Future<void> _handleConnect(
    BuildContext context,
    BuildContext dialogContext,
    TextEditingController apiKeyController,
    RxBool isProcessing,
    Rxn<String> statusMessage,
    RxBool isError,
  ) async {
    if (apiKeyController.text.isEmpty) {
      statusMessage.value = 'Please enter an API key';
      isError.value = true;
      return;
    }
    isProcessing.value = true;
    statusMessage.value = 'Testing connection...';
    isError.value = false;
    try {
      final testResult =
          await Get.find<IpqsService>().testAndConnect(apiKeyController.text);
      if (!testResult.success) {
        statusMessage.value = testResult.error ?? 'Connection failed';
        isError.value = true;
        isProcessing.value = false;
        return;
      }
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      showInfoBarToast(context,
          title: 'Success',
          message: 'IPQualityScore connected!',
          severity: InfoBarSeverity.success);
    } catch (e) {
      statusMessage.value = 'Error: $e';
      isError.value = true;
    } finally {
      isProcessing.value = false;
    }
  }
}
