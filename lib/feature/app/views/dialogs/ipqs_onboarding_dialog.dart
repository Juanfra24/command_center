import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/app/views/components/scoring_progress_display.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IpqsOnboardingDialog extends StatefulWidget {
  const IpqsOnboardingDialog._();

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const IpqsOnboardingDialog._(),
    );
  }

  @override
  State<IpqsOnboardingDialog> createState() => _IpqsOnboardingDialogState();
}

class _IpqsOnboardingDialogState extends State<IpqsOnboardingDialog> {
  final _apiKeyController = TextEditingController();
  final _isProcessing = false.obs;
  final _isCancelled = false.obs;
  final _statusMessage = Rxn<String>();
  final _isError = false.obs;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _isProcessing.close();
    _isCancelled.close();
    _statusMessage.close();
    _isError.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: const Text('Configure IPQualityScore'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Enter your IPQualityScore API key to enable IP scoring and fraud detection.'),
          const SizedBox(height: 16),
          Obx(() => InfoLabel(
                label: 'API Key',
                child: TextBox(
                  controller: _apiKeyController,
                  placeholder: 'Enter your IPQualityScore API key',
                  obscureText: true,
                  enabled: !_isProcessing.value,
                ),
              )),
          const SizedBox(height: 8),
          Text(
            'Get your free API key from ipqualityscore.com (1,000 free lookups/month)',
            style: TextStyle(
              fontSize: 12,
              color: FluentTheme.of(context).inactiveColor,
            ),
          ),
          Obx(() {
            if (_statusMessage.value == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ScoringProgressDisplay(
                statusMessage: _statusMessage,
                isError: _isError,
                isProcessing: _isProcessing,
              ),
            );
          }),
        ],
      ),
      actions: [
        Obx(() => Button(
              onPressed: _isProcessing.value
                  ? () {
                      _isCancelled.value = true;
                      _statusMessage.value = 'Cancelling...';
                    }
                  : () => Navigator.of(context).pop(),
              child: Text(_isProcessing.value ? 'Cancel Scoring' : 'Cancel'),
            )),
        _buildConnectButton(context),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext outerContext) {
    return Obx(() => FilledButton(
          onPressed:
              _isProcessing.value ? null : () => _handleConnect(outerContext),
          child: _isProcessing.value
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

  Future<void> _handleConnect(BuildContext outerContext) async {
    if (_apiKeyController.text.isEmpty) {
      _statusMessage.value = 'Please enter an API key';
      _isError.value = true;
      return;
    }

    _isProcessing.value = true;
    _isCancelled.value = false;
    _statusMessage.value = 'Testing connection...';
    _isError.value = false;

    try {
      final ipqsService = Get.find<IpqsService>();

      final testResult =
          await ipqsService.testAndConnect(_apiKeyController.text);

      if (!testResult.success) {
        _statusMessage.value = testResult.error ?? 'Connection failed';
        _isError.value = true;
        _isProcessing.value = false;
        return;
      }

      if (!_isCancelled.value) {
        _statusMessage.value = 'Scoring all proxy IPs...';
        try {
          final scoringController = Get.find<ProxyScoringController>();
          final scored = await scoringController.scoreAllCurrentIps();
          _statusMessage.value = 'Scored $scored IPs successfully!';
        } catch (e) {
          // Non-fatal
        }
      }

      try {
        final onboardingService = Get.find<OnboardingService>();
        await onboardingService.markInitialSyncComplete();
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (outerContext.mounted) {
          displayInfoBar(
            outerContext,
            builder: (ctx, close) {
              return InfoBar(
                title: const Text('Setup Complete'),
                content: Text(_isCancelled.value
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
      _statusMessage.value = 'Error: $e';
      _isError.value = true;
    } finally {
      _isProcessing.value = false;
    }
  }
}
