import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// An obscured text field for entering an API key, with a description and hint.
///
/// Disables the input when [isProcessing] is true.
class ApiKeyFormField extends StatelessWidget {
  const ApiKeyFormField({
    super.key,
    required this.controller,
    required this.isProcessing,
    required this.description,
    required this.hint,
    this.placeholder = 'Enter your API key',
  });

  final TextEditingController controller;
  final RxBool isProcessing;
  final String description;
  final String hint;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'API Key',
            child: TextBox(
              controller: controller,
              placeholder: placeholder,
              obscureText: true,
              enabled: !isProcessing.value,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
