import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class CharactersStatusSection extends StatelessWidget {
  const CharactersStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final counts = _getCharacterCounts();

    return Row(
      children: [
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.play_solid,
            label: 'Running',
            count: counts['running'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.pause,
            label: 'Stopped',
            count: counts['stopped'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCharacterStatusCard(
            context,
            icon: FluentIcons.people,
            label: 'Total',
            count: counts['total'] ?? 0,
            total: counts['total'] ?? 0,
            color: Colors.blue,
            showProgress: false,
          ),
        ),
      ],
    );
  }

  Map<String, int> _getCharacterCounts() {
    try {
      final statusController = Get.find<StatusController>();
      final accounts = statusController.accountList;
      final total = accounts.length;
      final runningProcesses = statusController.processClients;
      int running = 0;

      for (final account in accounts) {
        for (final character in account.characters) {
          if (runningProcesses.containsKey(character.name)) {
            final processInfo = runningProcesses[character.name];
            if (processInfo != null && processInfo.processId > 0) {
              running++;
            }
          }
        }
      }

      return {'total': total, 'running': running, 'stopped': total - running};
    } catch (_) {
      return {'total': 0, 'running': 0, 'stopped': 0};
    }
  }

  Widget _buildCharacterStatusCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required int total,
    required AccentColor color,
    bool showProgress = true,
  }) {
    final theme = FluentTheme.of(context);
    final percentage =
        total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.typography.bodyStrong?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count.toString(),
                style: theme.typography.title?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showProgress) ...[
                Text(
                  ' / $total',
                  style: theme.typography.body?.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Text(
                  '$percentage%',
                  style: theme.typography.caption?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ProgressBar(
              value: total > 0 ? (count / total * 100) : 0,
              backgroundColor: color.withValues(alpha: 0.2),
              activeColor: color,
            ),
          ],
        ],
      ),
    );
  }
}
