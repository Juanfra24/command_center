import 'package:command_center/config/services/watchdog/watchdog_service.dart';
import 'package:command_center/core/widgets/loading_button.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class BotFarmSummaryBar extends StatelessWidget {
  final Future<void> Function() onStartAll;
  final Future<void> Function() onStopAll;

  const BotFarmSummaryBar({
    super.key,
    required this.onStartAll,
    required this.onStopAll,
  });

  @override
  Widget build(BuildContext context) {
    // WatchdogService is registered in Phase 3 DI (after splash setup). Before
    // then — or if bot engine setup failed — the service is absent and
    // Get.find throws. Hide the bar in that state.
    if (!Get.isRegistered<WatchdogService>()) {
      return const SizedBox.shrink();
    }
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
            LoadingButton(
              label: 'Start All',
              loadingLabel: 'Starting...',
              icon: FluentIcons.play,
              onPressed: onStartAll,
            ),
            const SizedBox(width: 8),
            LoadingButton(
              label: 'Stop All',
              loadingLabel: 'Stopping...',
              icon: FluentIcons.stop,
              style: LoadingButtonStyle.outline,
              onPressed: onStopAll,
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
