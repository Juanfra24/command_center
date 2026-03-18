import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:command_center/feature/proxy/controller/proxy_scoring_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ProxyCommandBar extends StatelessWidget {
  final ProxyController controller;
  final ProxyScoringController scoringController;
  final VoidCallback onScoreAllIps;

  const ProxyCommandBar({
    super.key,
    required this.controller,
    required this.scoringController,
    required this.onScoreAllIps,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            if (scoringController.isIpqsConfigured.value)
              CommandBarButton(
                icon: scoringController.isScoring.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.shield),
                label: Text(scoringController.isScoring.value
                    ? 'Scoring...'
                    : 'Score All IPs'),
                onPressed:
                    scoringController.isScoring.value ? null : onScoreAllIps,
              ),
            if (controller.isWebshareConfigured.value)
              CommandBarButton(
                icon: controller.isSyncing.value || controller.isLoading.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.sync),
                label: Text(controller.isSyncing.value
                    ? 'Syncing...'
                    : 'Sync & Refresh'),
                onPressed:
                    controller.isSyncing.value || controller.isLoading.value
                        ? null
                        : () async {
                            await controller.syncWithWebshare();
                          },
              ),
          ],
        ));
  }
}
