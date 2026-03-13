import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/api_key_form_field.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IpqsConfigDialog extends StatefulWidget {
  const IpqsConfigDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const IpqsConfigDialog._(),
    );
  }

  @override
  State<IpqsConfigDialog> createState() => _IpqsConfigDialogState();
}

class _IpqsConfigDialogState extends State<IpqsConfigDialog> {
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
      configured = Get.find<IpqsService>().isConfigured.value;
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
      title: Text(_isConfigured
          ? 'IPQualityScore Configuration'
          : 'Configure IPQualityScore'),
      content: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isConfigured)
                const ApiKeyConfiguredBanner(
                  title: 'IPQualityScore Connected',
                  subtitle: 'IP scoring is active',
                )
              else
                ApiKeyFormField(
                  controller: _apiKeyController,
                  isProcessing: _isProcessing,
                  description:
                      'Enter your IPQualityScore API key to enable IP scoring.',
                  hint: 'Get your API key from ipqualityscore.com',
                  placeholder: 'Enter your IPQualityScore API key',
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
      final result = await Get.find<IpqsService>().clearApiKey();
      switch (result) {
        case Success():
          if (mounted) Navigator.of(context).pop();
          if (outerContext.mounted) {
            showInfoBarToast(outerContext,
                title: 'Unlinked',
                message: 'IPQualityScore has been disconnected.',
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
      final testResult =
          await Get.find<IpqsService>().testAndConnect(_apiKeyController.text);
      if (!testResult.success) {
        _statusMessage.value = testResult.error ?? 'Connection failed';
        _isError.value = true;
        _isProcessing.value = false;
        return;
      }
      if (mounted) Navigator.of(context).pop();
      if (outerContext.mounted) {
        showInfoBarToast(outerContext,
            title: 'Success',
            message: 'IPQualityScore connected!',
            severity: InfoBarSeverity.success);
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }
}
