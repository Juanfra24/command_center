import 'package:fluent_ui/fluent_ui.dart';

class SummaryCards extends StatelessWidget {
  final int totalAccounts;
  final int totalCharacters;
  final int runningProcesses;

  const SummaryCards({
    super.key,
    required this.totalAccounts,
    required this.totalCharacters,
    required this.runningProcesses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.contact,
            title: 'Total Accounts',
            value: totalAccounts.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.people,
            title: 'Characters',
            value: totalCharacters.toString(),
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: FluentIcons.play,
            title: 'Running',
            value: runningProcesses.toString(),
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required AccentColor color,
  }) {
    final theme = FluentTheme.of(context);

    return Card(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.typography.title?.copyWith(
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: theme.typography.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
