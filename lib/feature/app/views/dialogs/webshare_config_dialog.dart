import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/api_key_form_field.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class WebshareConfigDialog {
  WebshareConfigDialog._();

  static void show(BuildContext context) {
    final apiKeyController = TextEditingController();
    final isProcessing = false.obs;
    final statusMessage = Rxn<String>();
    final isError = false.obs;

    bool isConfigured = false;
    try {
      isConfigured = Get.find<WebshareService>().isConfigured.value;
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
                if (isConfigured)
                  const ApiKeyConfiguredBanner(
                    title: 'Webshare Connected',
                    subtitle: 'Your proxy slots are synced',
                  )
                else
                  ApiKeyFormField(
                    controller: apiKeyController,
                    isProcessing: isProcessing,
                    description:
                        'Enter your Webshare API key to sync your proxy slots.',
                    hint:
                        'You can find your API key in your Webshare dashboard under API settings.',
                    placeholder: 'Enter your Webshare API key',
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
              label: 'Connect & Sync',
              icon: FluentIcons.sync,
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
      final success = await Get.find<WebshareService>().clearApiKey();
      if (success) {
        try {
          statusMessage.value = 'Clearing proxy data...';
          await Get.find<ProxyController>().clearAllProxyData();
        } catch (e) {
          logger.w('ProxyController not available or error clearing data: $e');
        }
        try {
          await Get.find<OnboardingService>().resetOnboarding();
        } catch (e) {
          logger.w('OnboardingService not available: $e');
        }
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        if (context.mounted) {
          showInfoBarToast(context,
              title: 'Unlinked',
              message:
                  'Webshare has been disconnected and all proxy data cleared.',
              severity: InfoBarSeverity.warning);
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
      final webshareService = Get.find<WebshareService>();
      final testResult =
          await webshareService.testAndConnect(apiKeyController.text);
      if (!testResult.success) {
        statusMessage.value = testResult.error ?? 'Connection failed';
        isError.value = true;
        isProcessing.value = false;
        return;
      }
      statusMessage.value = 'Saving configuration...';
      final saved =
          await webshareService.saveApiKey(apiKeyController.text);
      if (!saved) {
        statusMessage.value = 'Failed to save API key';
        isError.value = true;
        isProcessing.value = false;
        return;
      }
      statusMessage.value = 'Syncing proxy slots...';
      bool syncSuccess = false;
      try {
        await Get.find<ProxyController>().syncWithWebshare();
        syncSuccess = true;
      } catch (e) {
        statusMessage.value = 'Sync failed: $e';
        isError.value = true;
      }
      if (syncSuccess) {
        try {
          await Get.find<OnboardingService>().markInitialSyncComplete();
        } catch (_) {}
      }
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      if (context.mounted) {
        showInfoBarToast(context,
            title: syncSuccess ? 'Success' : 'Partial Success',
            message: syncSuccess
                ? 'Webshare connected and proxies synced!'
                : 'Webshare connected but sync failed. Try syncing from the Proxy page.',
            severity: syncSuccess
                ? InfoBarSeverity.success
                : InfoBarSeverity.warning);
      }
    } catch (e) {
      statusMessage.value = 'Error: $e';
      isError.value = true;
    } finally {
      isProcessing.value = false;
    }
  }
}
