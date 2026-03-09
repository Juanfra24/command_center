import 'package:fluent_ui/fluent_ui.dart';

class IntegrationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isConfigured;
  final bool isComingSoon;
  final VoidCallback? onConfigure;

  const IntegrationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.isConfigured = false,
    this.isComingSoon = false,
    this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConfigured
              ? Colors.green.withValues(alpha: 0.5)
              : theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComingSoon
                  ? Colors.grey.withValues(alpha: 0.2)
                  : theme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isComingSoon ? Colors.grey : theme.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: theme.typography.bodyStrong),
                    if (isComingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Coming Soon',
                          style:
                              TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ),
                    ],
                    if (isConfigured) ...[
                      const SizedBox(width: 8),
                      Icon(FluentIcons.check_mark,
                          size: 14, color: Colors.green),
                    ],
                  ],
                ),
                Text(description, style: theme.typography.caption),
              ],
            ),
          ),
          if (!isComingSoon)
            Button(
              onPressed: onConfigure,
              child: Text(isConfigured ? 'Edit' : 'Configure'),
            ),
        ],
      ),
    );
  }
}
