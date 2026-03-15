import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class BotFarmSummaryBar extends StatelessWidget {
  final VoidCallback onStartAll;
  final VoidCallback onStopAll;

  const BotFarmSummaryBar({
    super.key,
    required this.onStartAll,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    final watchdog = Get.find<WatchdogService>();

    return Obx(() {
      // Force re-evaluation when trackedClients changes
      watchdog.trackedClients.length;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _statChip('Running', watchdog.runningCount, Colors.green),
            const SizedBox(width: 8),
            _statChip('Restarting', watchdog.restartingCount, Colors.orange),
            const SizedBox(width: 8),
            _statChip('Stopped', watchdog.stoppedCount, Colors.grey),
            const SizedBox(width: 8),
            _statChip('Banned', watchdog.bannedCount, Colors.red),
            const Spacer(),
            FilledButton(
              onPressed: onStartAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.play, size: 12),
                  SizedBox(width: 4),
                  Text('Start All'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: onStopAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.stop, size: 12),
                  SizedBox(width: 4),
                  Text('Stop All'),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
