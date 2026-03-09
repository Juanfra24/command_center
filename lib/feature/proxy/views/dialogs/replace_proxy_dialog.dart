import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_replacement_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ReplaceProxyDialog extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity currentIp;
  final ProxyReplacementController controller;

  const ReplaceProxyDialog({
    super.key,
    required this.slot,
    required this.currentIp,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required ProxySlotEntity slot,
    required ProxyIpAddressEntity currentIp,
    required ProxyReplacementController controller,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ReplaceProxyDialog(
        slot: slot,
        currentIp: currentIp,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool keepSameCountry = true;

    return StatefulBuilder(
      builder: (context, setDialogState) => ContentDialog(
        title: const Text('Replace Proxy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoBar(
              title: const Text('Low Score Detected'),
              content: Text(
                'This proxy IP (${currentIp.ipAddress}) has a score of ${currentIp.ipScore.toStringAsFixed(0)}, '
                'which is below the recommended threshold of 50. '
                'Replacing it will request a new IP from Webshare.',
              ),
              severity: InfoBarSeverity.warning,
            ),
            const SizedBox(height: 16),
            Text(
              'Current IP: ${currentIp.ipAddress}',
              style: FluentTheme.of(context).typography.body,
            ),
            Text(
              'Location: ${currentIp.cityName}, ${currentIp.countryCode}',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 16),
            Checkbox(
              checked: keepSameCountry,
              onChanged: (value) {
                setDialogState(() {
                  keepSameCountry = value ?? true;
                });
              },
              content: Text(
                'Keep same country (${currentIp.countryCode})',
              ),
            ),
            const SizedBox(height: 16),
            // Show remaining replacements
            Obx(() {
              final available = controller.replacementsAvailable.value;
              final total = controller.replacementsTotal.value;
              if (available != null && total != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InfoBar(
                    title:
                        Text('Replacements: $available / $total remaining'),
                    content: Text(
                      'You have used ${total - available} of $total replacements this period.',
                    ),
                    severity: available > 0
                        ? InfoBarSeverity.info
                        : InfoBarSeverity.error,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            InfoBar(
              title: const Text('Note'),
              content: const Text(
                'The replacement is processed asynchronously and may take a few seconds.',
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
          Obx(() {
            final available = controller.replacementsAvailable.value;
            final noReplacementsLeft = available != null && available <= 0;
            return FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.orange),
              ),
              onPressed: noReplacementsLeft
                  ? null
                  : () async {
                      Navigator.pop(context);

                      final result = await controller.replaceProxyIp(
                        slot,
                        keepSameCountry: keepSameCountry,
                      );

                      if (context.mounted) {
                        displayInfoBar(
                          context,
                          builder: (ctx, close) {
                            return InfoBar(
                              title:
                                  Text(result.success ? 'Success' : 'Error'),
                              content: Text(
                                result.success
                                    ? 'Proxy replaced successfully! The new IP has been synced.'
                                    : result.error ??
                                        'Failed to replace proxy',
                              ),
                              severity: result.success
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
              child: Text(noReplacementsLeft
                  ? 'No Replacements Left'
                  : 'Replace Proxy'),
            );
          }),
        ],
      ),
    );
  }
}
