import 'package:fluent_ui/fluent_ui.dart';

/// Shows a dismissible [InfoBar] toast using Fluent UI's [displayInfoBar].
void showInfoBarToast(
  BuildContext context, {
  required String title,
  required String message,
  required InfoBarSeverity severity,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      displayInfoBar(
        context,
        builder: (ctx, close) => InfoBar(
          title: Text(title),
          content: Text(message),
          severity: severity,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  });
}
