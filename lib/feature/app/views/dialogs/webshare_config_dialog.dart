import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/api_key_form_field.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class WebshareConfigDialog extends StatefulWidget {
  const WebshareConfigDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const WebshareConfigDialog._(),
    );
  }

  @override
  State<WebshareConfigDialog> createState() => _WebshareConfigDialogState();
}

class _WebshareConfigDialogState extends State<WebshareConfigDialog> {
  final _apiKeyController = TextEditingController();
  final _isProcessing = false.obs;
  final _statusMessage = Rxn<String>();
  final _isError = false.obs;

  late final bool _isConfigured;

  @override
  void initState() {
    super.initState();
    bool configured = false;
    try {
      configured = Get.find<WebshareService>().isConfigured.value;
    } catch (_) {}
    _isConfigured = configured;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _isProcessing.close();
    _statusMessage.close();
    _isError.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title:
          Text(_isConfigured ? 'Webshare Configuration' : 'Configure Webshare'),
      content: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isConfigured)
                const ApiKeyConfiguredBanner(
                  title: 'Webshare Connected',
                  subtitle: 'Your proxy slots are synced',
                )
              else
                ApiKeyFormField(
                  controller: _apiKeyController,
                  isProcessing: _isProcessing,
                  description:
                      'Enter your Webshare API key to sync your proxy slots.',
                  hint:
                      'You can find your API key in your Webshare dashboard under API settings.',
                  placeholder: 'Enter your Webshare API key',
                ),
              ProcessingStatusBar(
                statusMessage: _statusMessage,
                isError: _isError,
                isProcessing: _isProcessing,
              ),
            ],
          )),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_isConfigured)
          UnlinkActionButton(
            isProcessing: _isProcessing,
            onUnlink: () => _handleUnlink(context),
          )
        else
          ConnectActionButton(
            isProcessing: _isProcessing,
            label: 'Connect & Sync',
            icon: FluentIcons.sync,
            onConnect: () => _handleConnect(context),
          ),
      ],
    );
  }

  Future<void> _handleUnlink(BuildContext outerContext) async {
    _isProcessing.value = true;
    _statusMessage.value = 'Unlinking...';
    _isError.value = false;
    try {
      final result = await Get.find<WebshareService>().clearApiKey();
      switch (result) {
        case Success():
          try {
            _statusMessage.value = 'Clearing proxy data...';
            await Get.find<ProxyController>().clearAllProxyData();
          } catch (e) {
            logger
                .w('ProxyController not available or error clearing data: $e');
          }
          try {
            await Get.find<OnboardingService>().resetOnboarding();
          } catch (e) {
            logger.w('OnboardingService not available: $e');
          }
          if (mounted) Navigator.of(context).pop();
          if (outerContext.mounted) {
            showInfoBarToast(outerContext,
                title: 'Unlinked',
                message:
                    'Webshare has been disconnected and all proxy data cleared.',
                severity: InfoBarSeverity.warning);
          }
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }

  Future<void> _handleConnect(BuildContext outerContext) async {
    if (_apiKeyController.text.isEmpty) {
      _statusMessage.value = 'Please enter an API key';
      _isError.value = true;
      return;
    }
    _isProcessing.value = true;
    _statusMessage.value = 'Testing connection...';
    _isError.value = false;
    try {
      final webshareService = Get.find<WebshareService>();
      final testResult =
          await webshareService.testAndConnect(_apiKeyController.text);
      switch (testResult) {
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
          _isProcessing.value = false;
          return;
        case Success():
          break;
      }
      _statusMessage.value = 'Saving configuration...';
      final saveResult =
          await webshareService.saveApiKey(_apiKeyController.text);
      switch (saveResult) {
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
          _isProcessing.value = false;
          return;
        case Success():
          break;
      }
      _statusMessage.value = 'Syncing proxy slots...';
      bool syncSuccess = false;
      try {
        await Get.find<ProxyController>().syncWithWebshare();
        syncSuccess = true;
      } catch (e) {
        _statusMessage.value = 'Sync failed: $e';
        _isError.value = true;
      }
      if (syncSuccess) {
        try {
          await Get.find<OnboardingService>().markInitialSyncComplete();
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop();
      if (outerContext.mounted) {
        showInfoBarToast(outerContext,
            title: syncSuccess ? 'Success' : 'Partial Success',
            message: syncSuccess
                ? 'Webshare connected and proxies synced!'
                : 'Webshare connected but sync failed. Try syncing from the Proxy page.',
            severity: syncSuccess
                ? InfoBarSeverity.success
                : InfoBarSeverity.warning);
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }
}
