import 'package:fluent_ui/fluent_ui.dart';

class BulkStartConfirmationDialog extends StatelessWidget {
  final int withScripts;
  final int withoutScripts;

  const BulkStartConfirmationDialog({
    super.key,
    required this.withScripts,
    required this.withoutScripts,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int withScripts,
    required int withoutScripts,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => BulkStartConfirmationDialog(
          withScripts: withScripts,
          withoutScripts: withoutScripts,
        ),
      );

  int get _total => withScripts + withoutScripts;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Start Characters'),
      content: Text(
        '$withoutScripts of $_total characters have no script assigned. '
        'Start the $withScripts that do?',
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Start $withScripts'),
        ),
      ],
    );
  }
}
