import 'package:command_center/feature/proxy/controller/proxy_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class IntegrationRequiredView extends StatelessWidget {
  final ProxyController controller;
  final VoidCallback? onNavigateToSettings;

  const IntegrationRequiredView({
    super.key,
    required this.controller,
    this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Card(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                FluentIcons.plug_connected,
                size: 40,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Webshare Integration Required',
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                'To manage your proxy slots, you need to connect your Webshare account. '
                'Go to Settings > Integrations to configure your API key.',
                textAlign: TextAlign.center,
                style: theme.typography.body,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onNavigateToSettings,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.settings),
                  SizedBox(width: 8),
                  Text('Go to Settings'),
                ],
              ),
            ),
            Obx(() {
              if (controller.lastSyncError.value != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: InfoBar(
                    title: const Text('Error'),
                    content: Text(controller.lastSyncError.value!),
                    severity: InfoBarSeverity.error,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }
}
