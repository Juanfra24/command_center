import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AddSlotDialog extends StatelessWidget {
  final ProxyController controller;

  const AddSlotDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context,
      {required ProxyController controller}) {
    return showDialog(
      context: context,
      builder: (_) => AddSlotDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final portController = TextEditingController(text: '8080');

    return ContentDialog(
      title: const Text('Add Proxy Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: 'Slot Name',
            child: TextBox(
              controller: nameController,
              placeholder: 'e.g., US Proxy 1',
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Username',
            child: TextBox(
              controller: usernameController,
              placeholder: 'Webshare username',
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Password',
            child: TextBox(
              controller: passwordController,
              placeholder: 'Webshare password',
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Port',
            child: TextBox(
              controller: portController,
              placeholder: '8080',
            ),
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
            final newSlot = ProxySlotEntity(
              id: null,
              slotName: nameController.text,
              slotNumber: controller.totalSlots + 1,
              username: usernameController.text,
              password: passwordController.text,
              port: int.tryParse(portController.text) ?? 8080,
              createdAt: DateTime.now(),
              lastUpdated: DateTime.now(),
              totalIpChanges: 0,
              isActive: true,
            );
            await controller.addProxySlot(newSlot);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
