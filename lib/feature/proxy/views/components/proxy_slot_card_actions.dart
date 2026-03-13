import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Placeholder for future per-card action buttons.
/// Currently slot actions are in SlotHeader (detail pane).
class ProxySlotCardActions extends StatelessWidget {
  final ProxySlotEntity slot;

  const ProxySlotCardActions({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
