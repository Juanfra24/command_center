import 'package:fluent_ui/fluent_ui.dart';

class SetupChecklistItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isComplete;
  final VoidCallback? onTap;
  final bool isEnabled;

  const SetupChecklistItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isComplete,
    this.onTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isClickable = !isComplete && isEnabled;

    return GestureDetector(
      onTap: isClickable ? onTap : null,
      child: MouseRegion(
        cursor:
            isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? Colors.green.withValues(alpha: 0.1)
                  : theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isComplete
                    ? Colors.green.withValues(alpha: 0.5)
                    : theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete ? FluentIcons.check_mark : FluentIcons.circle_ring,
                  color: isComplete
                      ? Colors.green
                      : (isEnabled ? theme.accentColor : Colors.grey),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.typography.bodyStrong?.copyWith(
                          decoration:
                              isComplete ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(subtitle, style: theme.typography.caption),
                    ],
                  ),
                ),
                if (isClickable)
                  Icon(
                    FluentIcons.chevron_right,
                    size: 14,
                    color: theme.accentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
