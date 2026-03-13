import 'package:command_center/config/services/app_config_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class AutoRotationSettings extends StatelessWidget {
  final AppConfigService? appConfigService;

  const AutoRotationSettings({super.key, this.appConfigService});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final AppConfigService resolvedService;
    if (appConfigService != null) {
      resolvedService = appConfigService!;
    } else {
      try {
        resolvedService = Get.find<AppConfigService>();
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.sync, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('Proxy Auto-Rotation', style: theme.typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final enabled = resolvedService.autoRotationEnabled.value;
            final threshold =
                resolvedService.autoRotationThreshold.value.toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToggleSwitch(
                  checked: enabled,
                  onChanged: (value) =>
                      resolvedService.saveAutoRotationEnabled(value),
                  content:
                      const Text('Automatically replace low-scoring proxies'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Replace IPs scoring below ${threshold.round()}',
                  style: theme.typography.body,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: threshold,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: enabled
                      ? (value) =>
                          resolvedService.autoRotationThreshold.value =
                              value.round()
                      : null,
                  onChangeEnd: enabled
                      ? (value) => resolvedService
                          .saveAutoRotationThreshold(value.round())
                      : null,
                  label: '${threshold.round()}',
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Text('Runs automatically after IP scoring',
              style: theme.typography.caption),
        ],
      ),
    );
  }
}
