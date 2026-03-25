import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_replacement_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ChangeIpDialog extends StatefulWidget {
  final ProxySlotEntity slot;
  final ProxyReplacementController controller;

  const ChangeIpDialog({
    super.key,
    required this.slot,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required ProxySlotEntity slot,
    required ProxyReplacementController controller,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeIpDialog(slot: slot, controller: controller),
    );
  }

  @override
  State<ChangeIpDialog> createState() => _ChangeIpDialogState();
}

class _ChangeIpDialogState extends State<ChangeIpDialog> {
  bool _isProcessing = false;

  Future<void> _handleRotate() async {
    setState(() => _isProcessing = true);

    final success = await widget.controller.rotateSlotIp(widget.slot);

    if (!mounted) return;

    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(success ? 'Success' : 'Error'),
        content: Text(
          success
              ? 'IP replaced successfully.'
              : Get.find<ProxyController>().lastSyncError.value ??
                  'Failed to rotate IP',
        ),
        severity: success ? InfoBarSeverity.success : InfoBarSeverity.error,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Rotate IP Address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will request a new IP address from Webshare for this proxy slot.',
          ),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                ProgressRing(strokeWidth: 3),
                SizedBox(width: 12),
                Text('Replacing IP address...'),
              ],
            ),
            const SizedBox(height: 8),
          ] else
            InfoBar(
              title: const Text('Note'),
              content: const Text(
                'The new IP will be automatically synced after the rotation is complete.',
              ),
              severity: InfoBarSeverity.info,
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _handleRotate,
          child: const Text('Rotate IP'),
        ),
      ],
    );
  }
}
