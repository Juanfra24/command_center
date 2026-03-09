import 'package:fluent_ui/fluent_ui.dart';

/// A banner showing that an API service is connected and configured.
///
/// Displays a green container with a checkmark, a [title] and [subtitle],
/// followed by a hint to unlink before reconfiguring.
class ApiKeyConfiguredBanner extends StatelessWidget {
  const ApiKeyConfiguredBanner({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.check_mark, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'To use a different API key, unlink the current configuration first.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
