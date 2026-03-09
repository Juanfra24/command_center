import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/feature/app/views/components/about_card.dart';
import 'package:command_center/feature/app/views/components/integration_tile.dart';
import 'package:command_center/feature/app/views/dialogs/ipqs_config_dialog.dart';
import 'package:command_center/feature/app/views/dialogs/webshare_config_dialog.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SettingsSection extends StatelessWidget {
  final bool isDark;

  const SettingsSection({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Settings')),
      children: [
        _buildAppearanceCard(context),
        const SizedBox(height: 16),
        _buildMusicCard(context),
        const SizedBox(height: 16),
        _buildIntegrationsCard(context),
        const SizedBox(height: 16),
        const AboutCard(),
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance',
              style: FluentTheme.of(context).typography.bodyLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Theme Mode'),
              const Spacer(),
              ToggleSwitch(
                checked: isDark,
                onChanged: (value) {
                  ThemeManage.changeThemeMode();
                },
                content: Text(isDark ? 'Dark Mode' : 'Light Mode'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMusicCard(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.music_note,
                  color: FluentTheme.of(context).accentColor),
              const SizedBox(width: 8),
              Text('Music',
                  style: FluentTheme.of(context).typography.bodyLarge),
            ],
          ),
          const SizedBox(height: 16),
          _buildMusicVolumeControl(context),
        ],
      ),
    );
  }

  Widget _buildMusicVolumeControl(BuildContext context) {
    try {
      final musicController = Get.find<MusicController>();
      return Obx(() => Row(
            children: [
              Icon(
                musicController.volume.value == 0
                    ? FluentIcons.volume0
                    : musicController.volume.value < 0.5
                        ? FluentIcons.volume1
                        : FluentIcons.volume3,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: musicController.volume.value * 100,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    musicController.setVolume(value / 100);
                  },
                  label:
                      '${(musicController.volume.value * 100).round()}%',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${(musicController.volume.value * 100).round()}%',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ),
            ],
          ));
    } catch (e) {
      return const Text('Music controller not available');
    }
  }

  Widget _buildIntegrationsCard(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.plug_connected,
                  color: FluentTheme.of(context).accentColor),
              const SizedBox(width: 8),
              Text('Integrations',
                  style: FluentTheme.of(context).typography.bodyLarge),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(fontSize: 10, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWebshareIntegrationTile(context),
          const SizedBox(height: 12),
          _buildIpqsIntegrationTile(context),
          const SizedBox(height: 12),
          IntegrationTile(
            icon: FluentIcons.message,
            title: 'WhatsApp',
            description: 'Receive notifications via WhatsApp',
            isComingSoon: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWebshareIntegrationTile(BuildContext context) {
    return Obx(() {
      bool isConfigured = false;
      try {
        final webshareService = Get.find<WebshareService>();
        isConfigured = webshareService.isConfigured.value;
      } catch (_) {}

      return IntegrationTile(
        icon: FluentIcons.globe,
        title: 'Webshare',
        description: 'Proxy service integration for IP management',
        isConfigured: isConfigured,
        onConfigure: () => WebshareConfigDialog.show(context),
      );
    });
  }

  Widget _buildIpqsIntegrationTile(BuildContext context) {
    return Obx(() {
      bool isConfigured = false;
      try {
        final ipqsService = Get.find<IpqsService>();
        isConfigured = ipqsService.isConfigured.value;
      } catch (_) {}

      return IntegrationTile(
        icon: FluentIcons.shield,
        title: 'IPQualityScore',
        description: 'IP scoring and fraud detection service',
        isConfigured: isConfigured,
        onConfigure: () => IpqsConfigDialog.show(context),
      );
    });
  }
}
