import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AddSlotDialog extends StatefulWidget {
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
  State<AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<AddSlotDialog> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '8080');

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Add Proxy Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: 'Slot Name',
            child: TextBox(
              controller: _nameController,
              placeholder: 'e.g., US Proxy 1',
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Username',
            child: TextBox(
              controller: _usernameController,
              placeholder: 'Webshare username',
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Password',
            child: TextBox(
              controller: _passwordController,
              placeholder: 'Webshare password',
              obscureText: true,
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Port',
            child: TextBox(
              controller: _portController,
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
            // Validate required fields
            if (_nameController.text.trim().isEmpty) {
              await displayInfoBar(context, builder: (ctx, close) {
                return const InfoBar(
                  title: Text('Slot name is required'),
                  severity: InfoBarSeverity.error,
                );
              });
              return;
            }
            if (_usernameController.text.trim().isEmpty ||
                _passwordController.text.trim().isEmpty) {
              await displayInfoBar(context, builder: (ctx, close) {
                return const InfoBar(
                  title: Text('Username and password are required'),
                  severity: InfoBarSeverity.error,
                );
              });
              return;
            }
            final port = int.tryParse(_portController.text);
            if (port == null || port < 1 || port > 65535) {
              await displayInfoBar(context, builder: (ctx, close) {
                return const InfoBar(
                  title: Text('Port must be between 1 and 65535'),
                  severity: InfoBarSeverity.error,
                );
              });
              return;
            }
            final newSlot = ProxySlotEntity(
              id: null,
              slotName: _nameController.text.trim(),
              slotNumber: widget.controller.totalSlots + 1,
              username: _usernameController.text.trim(),
              password: _passwordController.text.trim(),
              port: port,
              createdAt: DateTime.now(),
              lastUpdated: DateTime.now(),
              totalIpChanges: 0,
              isActive: true,
            );
            await widget.controller.addProxySlot(newSlot);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
