import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class QuickActionsSection extends StatelessWidget {
  final Function(int)? onNavigateToIndex;

  const QuickActionsSection({super.key, this.onNavigateToIndex});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainMenuController>();
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: theme.typography.subtitle),
        const SizedBox(height: 12),
        Obx(() => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionCard(
                  icon: FluentIcons.shield_alert,
                  title: 'Score All IPs',
                  description: 'Run IPQS checks on all active proxy IPs',
                  isLoading: controller.isScoringAll.value,
                  onTap: () => controller.scoreAllIps(),
                ),
                _ActionCard(
                  icon: FluentIcons.sync,
                  title: 'Sync Proxies',
                  description: 'Fetch latest proxy list from Webshare',
                  isLoading: controller.isSyncing.value,
                  onTap: () => controller.syncProxies(),
                ),
                _ActionCard(
                  icon: FluentIcons.add_friend,
                  title: 'New Character',
                  description: 'Add a new character to an account',
                  onTap: () => onNavigateToIndex?.call(1),
                ),
                _ActionCard(
                  icon: FluentIcons.settings,
                  title: 'Settings',
                  description: 'Configure API keys and preferences',
                  onTap: () => onNavigateToIndex?.call(3),
                ),
              ],
            )),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDisabled = isLoading || onTap == null;

    Widget card = Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: ProgressRing(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 20,
                  color: isDisabled
                      ? theme.resources.textFillColorSecondary
                      : theme.accentColor,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.typography.bodyStrong?.copyWith(
              color: isDisabled ? theme.resources.textFillColorSecondary : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );

    if (!isDisabled) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }

    return card;
  }
}
