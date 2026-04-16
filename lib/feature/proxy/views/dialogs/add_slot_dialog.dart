import 'package:command_center/config/theme/status_colors.dart';
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

  // Inline validation error messages
  String? _nameError;
  String? _usernameError;
  String? _passwordError;
  String? _portError;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _nameError =
          _nameController.text.trim().isEmpty ? 'Slot name is required' : null;
      _usernameError = _usernameController.text.trim().isEmpty
          ? 'Username is required'
          : null;
      _passwordError = _passwordController.text.trim().isEmpty
          ? 'Password is required'
          : null;
      final port = int.tryParse(_portController.text);
      _portError = (port == null || port < 1 || port > 65535)
          ? 'Port must be between 1 and 65535'
          : null;
    });
    valid = _nameError == null &&
        _usernameError == null &&
        _passwordError == null &&
        _portError == null;
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Add Proxy Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: 'Slot Name *',
            child: TextBox(
              controller: _nameController,
              placeholder: 'e.g., US Proxy 1',
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          if (_nameError != null) _fieldError(_nameError!),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Username *',
            child: TextBox(
              controller: _usernameController,
              placeholder: 'Webshare username',
              onChanged: (_) {
                if (_usernameError != null) {
                  setState(() => _usernameError = null);
                }
              },
            ),
          ),
          if (_usernameError != null) _fieldError(_usernameError!),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Password *',
            child: TextBox(
              controller: _passwordController,
              placeholder: 'Webshare password',
              obscureText: true,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
            ),
          ),
          if (_passwordError != null) _fieldError(_passwordError!),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Port *',
            child: TextBox(
              controller: _portController,
              placeholder: '8080',
              onChanged: (_) {
                if (_portError != null) setState(() => _portError = null);
              },
            ),
          ),
          if (_portError != null) _fieldError(_portError!),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_validate()) return;
            final port = int.parse(_portController.text);
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

  Widget _fieldError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12,
            color: StatusColors.of(context).error,
          ),
        ),
      ),
    );
  }
}
