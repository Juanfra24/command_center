import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/core/resource/result.dart';
import 'package:command_center/feature/app/views/components/api_key_configured_banner.dart';
import 'package:command_center/feature/app/views/components/connect_action_button.dart';
import 'package:command_center/feature/app/views/components/info_bar_helper.dart';
import 'package:command_center/feature/app/views/components/processing_status_bar.dart';
import 'package:command_center/feature/app/views/components/unlink_action_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ImapConfigDialog extends StatefulWidget {
  const ImapConfigDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ImapConfigDialog._(),
    );
  }

  @override
  State<ImapConfigDialog> createState() => _ImapConfigDialogState();
}

class _ImapConfigDialogState extends State<ImapConfigDialog> {
  final _hostController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _isProcessing = false.obs;
  final _statusMessage = Rxn<String>();
  final _isError = false.obs;

  late final bool _isConfigured;

  @override
  void initState() {
    super.initState();
    bool configured = false;
    try {
      final service = Get.find<ImapConfigService>();
      configured = service.isConfigured.value;
      _hostController.text = service.cachedHost ?? 'imap.gmail.com';
    } catch (_) {}
    if (_hostController.text.isEmpty) {
      _hostController.text = 'imap.gmail.com';
    }
    _isConfigured = configured;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _userController.dispose();
    _passController.dispose();
    _isProcessing.close();
    _statusMessage.close();
    _isError.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: Text(
          _isConfigured ? 'Email Configuration' : 'Configure Email (IMAP)'),
      content: _isConfigured
          ? _buildConfiguredContent()
          : _buildFormContent(context),
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
            label: 'Save',
            icon: FluentIcons.save,
            onConnect: () => _handleSave(context),
          ),
      ],
    );
  }

  Widget _buildConfiguredContent() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ApiKeyConfiguredBanner(
            title: 'Email Connected',
            subtitle: 'IMAP verification is active',
          ),
          ProcessingStatusBar(
              statusMessage: _statusMessage,
              isError: _isError,
              isProcessing: _isProcessing),
        ],
      );

  Widget _buildFormContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configure your IMAP mailbox for Jagex email verification.'),
        const SizedBox(height: 16),
        ..._buildFormFields(),
        const SizedBox(height: 8),
        Text(
          'Uses IMAP over SSL (port 993). For Gmail, use an App Password '
          '(Google Account → Security → App Passwords), not your regular password.',
          style: TextStyle(
            fontSize: 12,
            color: FluentTheme.of(context).inactiveColor,
          ),
        ),
        ProcessingStatusBar(
          statusMessage: _statusMessage,
          isError: _isError,
          isProcessing: _isProcessing,
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    return [
      Obx(() => InfoLabel(
            label: 'IMAP Host',
            child: TextBox(
              controller: _hostController,
              placeholder: 'imap.gmail.com',
              enabled: !_isProcessing.value,
            ),
          )),
      const SizedBox(height: 12),
      Obx(() => InfoLabel(
            label: 'Email / Username',
            child: TextBox(
              controller: _userController,
              placeholder: 'your@email.com',
              enabled: !_isProcessing.value,
            ),
          )),
      const SizedBox(height: 12),
      Obx(() => InfoLabel(
            label: 'Password',
            child: TextBox(
              controller: _passController,
              placeholder: 'IMAP password',
              obscureText: true,
              enabled: !_isProcessing.value,
            ),
          )),
    ];
  }

  Future<void> _handleSave(BuildContext outerContext) async {
    if (_hostController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      _statusMessage.value = 'All fields are required';
      _isError.value = true;
      return;
    }
    await _runAsync('Saving...', outerContext, () async {
      return Get.find<ImapConfigService>().saveConfig(
        host: _hostController.text,
        user: _userController.text,
        pass: _passController.text,
      );
    }, successTitle: 'Success', successMessage: 'Email (IMAP) configured!');
  }

  Future<void> _handleUnlink(BuildContext outerContext) async {
    await _runAsync('Unlinking...', outerContext, () async {
      return Get.find<ImapConfigService>().clearConfig();
    },
        successTitle: 'Unlinked',
        successMessage: 'Email (IMAP) has been disconnected.',
        severity: InfoBarSeverity.warning);
  }

  Future<void> _runAsync(
    String statusText,
    BuildContext outerContext,
    Future<Result<void>> Function() action, {
    required String successTitle,
    required String successMessage,
    InfoBarSeverity severity = InfoBarSeverity.success,
  }) async {
    _isProcessing.value = true;
    _statusMessage.value = statusText;
    _isError.value = false;
    try {
      final result = await action();
      switch (result) {
        case Success():
          if (mounted) Navigator.of(context).pop();
          if (outerContext.mounted) {
            showInfoBarToast(outerContext,
                title: successTitle,
                message: successMessage,
                severity: severity);
          }
        case Failure(:final message):
          _statusMessage.value = message;
          _isError.value = true;
      }
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      if (mounted) _isProcessing.value = false;
    }
  }
}
