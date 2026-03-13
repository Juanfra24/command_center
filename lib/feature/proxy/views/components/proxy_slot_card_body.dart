import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ProxySlotCardBody extends StatelessWidget {
  final ProxySlotEntity slot;
  final ProxyIpAddressEntity? currentIp;

  const ProxySlotCardBody({
    super.key,
    required this.slot,
    this.currentIp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildSlotInfoChip(
          icon: FluentIcons.refresh,
          label: '${slot.totalIpChanges} changes',
        ),
        const SizedBox(width: 8),
        if (currentIp != null)
          _buildSlotInfoChip(
            icon: FluentIcons.globe,
            label: currentIp!.countryCode,
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildSlotInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
