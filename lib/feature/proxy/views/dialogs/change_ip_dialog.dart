import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ChangeIpDialog extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyController controller;

  const ChangeIpDialog({
    super.key,
    required this.slot,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required ProxySlotEntity slot,
    required ProxyController controller,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ChangeIpDialog(slot: slot, controller: controller),
    );
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);

            final success = await controller.rotateSlotIp(slot);

            if (context.mounted) {
              displayInfoBar(
                context,
                builder: (context, close) {
                  return InfoBar(
                    title: Text(success ? 'Success' : 'Error'),
                    content: Text(
                      success
                          ? 'IP rotation initiated. Syncing...'
                          : controller.lastSyncError.value ??
                              'Failed to rotate IP',
                    ),
                    severity: success
                        ? InfoBarSeverity.success
                        : InfoBarSeverity.error,
                    action: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: close,
                    ),
                  );
                },
              );
            }
          },
          child: const Text('Rotate IP'),
        ),
      ],
    );
  }
}
