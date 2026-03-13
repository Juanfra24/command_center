import 'package:command_center/feature/app/views/components/about_links_section.dart';
import 'package:command_center/feature/app/views/components/about_version_info.dart';
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
          const AboutVersionInfo(),
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
          const AboutLinksSection(),
        ],
      ),
    );
  }
}
