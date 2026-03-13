import 'package:fluent_ui/fluent_ui.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              FluentIcons.history,
              size: 32,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 8),
            Text('No recent activity', style: theme.typography.caption),
          ],
        ),
      ),
    );
  }
}
