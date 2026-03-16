import 'package:fluent_ui/fluent_ui.dart';

/// Thin wrapper around Fluent UI's [Expander] with a consistent badge slot.
/// Uses the native Expander for styling, animation, keyboard, and accessibility.
class CollapsibleSection extends StatelessWidget {
  final String title;
  final Widget? badge;
  final Widget content;
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.badge,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expander(
      header: Row(
        children: [
          Text(title),
          if (badge != null) ...[
            const Spacer(),
            badge!,
          ],
        ],
      ),
      content: content,
      initiallyExpanded: initiallyExpanded,
    );
  }
}
