import 'package:fluent_ui/fluent_ui.dart';

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.accentColor,
                      theme.accentColor.lighter,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    FluentIcons.command_prompt,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Command Center',
                      style: theme.typography.title?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                theme.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'v0.4.0',
                            style: TextStyle(
                              color: theme.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FluentIcons.check_mark,
                                size: 10,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Stable',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your comprehensive solution for managing and orchestrating '
                  'automated RuneScape operations. Control proxies, monitor '
                  'characters, and streamline your workflow all in one place.',
                  style: theme.typography.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
      ),
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
