import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ReplaceProxyButton extends StatelessWidget {
  final RxBool isReplacing;
  final ProxyIpAddressEntity ip;
  final ProxySlotEntity slot;
  final void Function(
          BuildContext context, ProxySlotEntity slot, ProxyIpAddressEntity ip)
      onReplace;

  const ReplaceProxyButton({
    super.key,
    required this.isReplacing,
    required this.ip,
    required this.slot,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    if (!ip.hasBeenScored || ip.fraudScore <= 60) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final replacing = isReplacing.value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.orange),
          ),
          onPressed: replacing ? null : () => onReplace(context, slot, ip),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replacing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: ProgressRing(strokeWidth: 2),
                )
              else
                const Icon(FluentIcons.switch_widget, size: 16),
              const SizedBox(width: 8),
              Text(replacing ? 'Replacing...' : 'Replace'),
            ],
          ),
        ),
      );
    });
  }
}
