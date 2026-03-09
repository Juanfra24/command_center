import 'package:fluent_ui/fluent_ui.dart';

class InfoBanner extends StatelessWidget {
  final String title;
  final String description;

  const InfoBanner({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.info, color: theme.accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.typography.bodyStrong),
                const SizedBox(height: 4),
                Text(description, style: theme.typography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
