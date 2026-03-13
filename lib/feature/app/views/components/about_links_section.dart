import 'package:fluent_ui/fluent_ui.dart';

class AboutLinksSection extends StatelessWidget {
  const AboutLinksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: FluentIcons.globe,
                label: 'Proxy Management',
                description: 'Full control',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.resources.dividerStrokeColorDefault,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: FluentIcons.people,
                label: 'Multi-Account',
                description: 'Support',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: theme.resources.dividerStrokeColorDefault,
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: FluentIcons.shield,
                label: 'IP Scoring',
                description: 'Integration',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(
              FluentIcons.heart,
              size: 14,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Built with Flutter',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '\u00A9 2024-2026',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
  }) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.accentColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            description,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
