import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/imap/imap_config_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/feature/app/views/components/about_card.dart';
import 'package:command_center/feature/app/views/components/integration_tile.dart';
import 'package:command_center/feature/app/views/dialogs/imap_config_dialog.dart';
import 'package:command_center/feature/app/views/dialogs/ipqs_config_dialog.dart';
import 'package:command_center/feature/app/views/dialogs/webshare_config_dialog.dart';
import 'package:command_center/feature/app/views/sections/auto_rotation_settings.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class SettingsSection extends StatelessWidget {
  final bool isDark;
  final MusicController? musicController;
  final WebshareService? webshareService;
  final IpqsService? ipqsService;
  final AppConfigService? appConfigService;
  final ImapConfigService? imapConfigService;

  const SettingsSection({
    super.key,
    required this.isDark,
    this.musicController,
    this.webshareService,
    this.ipqsService,
    this.appConfigService,
    this.imapConfigService,
  });

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Settings')),
      children: [
        _buildAppearanceCard(context),
        const SizedBox(height: 16),
        _buildMusicCard(context),
        const SizedBox(height: 16),
        AutoRotationSettings(appConfigService: appConfigService),
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
    final mc = musicController;
    if (mc == null) return const Text('Music controller not available');
    return Obx(() => Row(
          children: [
            Icon(
              mc.volume.value == 0
                  ? FluentIcons.volume0
                  : mc.volume.value < 0.5
                      ? FluentIcons.volume1
                      : FluentIcons.volume3,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: mc.volume.value * 100,
                min: 0,
                max: 100,
                onChanged: (value) {
                  mc.setVolume(value / 100);
                },
                label: '${(mc.volume.value * 100).round()}%',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                '${(mc.volume.value * 100).round()}%',
                style: FluentTheme.of(context).typography.caption,
              ),
            ),
          ],
        ));
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          _buildImapIntegrationTile(context),
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
    final ws = webshareService;
    if (ws == null) {
      return IntegrationTile(
        icon: FluentIcons.globe,
        title: 'Webshare',
        description: 'Proxy service integration for IP management',
        isConfigured: false,
        onConfigure: () => WebshareConfigDialog.show(context),
      );
    }
    return Obx(() => IntegrationTile(
          icon: FluentIcons.globe,
          title: 'Webshare',
          description: 'Proxy service integration for IP management',
          isConfigured: ws.isConfigured.value,
          onConfigure: () => WebshareConfigDialog.show(context),
        ));
  }

  Widget _buildIpqsIntegrationTile(BuildContext context) {
    final ipqs = ipqsService;
    if (ipqs == null) {
      return IntegrationTile(
        icon: FluentIcons.shield,
        title: 'IPQualityScore',
        description: 'IP scoring and fraud detection service',
        isConfigured: false,
        onConfigure: () => IpqsConfigDialog.show(context),
      );
    }
    return Obx(() => IntegrationTile(
          icon: FluentIcons.shield,
          title: 'IPQualityScore',
          description: 'IP scoring and fraud detection service',
          isConfigured: ipqs.isConfigured.value,
          onConfigure: () => IpqsConfigDialog.show(context),
        ));
  }

  Widget _buildImapIntegrationTile(BuildContext context) {
    final imap = imapConfigService;
    if (imap == null) {
      return IntegrationTile(
        icon: FluentIcons.mail,
        title: 'Email (IMAP)',
        description: 'Email verification for account creation',
        isConfigured: false,
        onConfigure: () => ImapConfigDialog.show(context),
      );
    }
    return Obx(() => IntegrationTile(
          icon: FluentIcons.mail,
          title: 'Email (IMAP)',
          description: 'Email verification for account creation',
          isConfigured: imap.isConfigured.value,
          onConfigure: () => ImapConfigDialog.show(context),
        ));
  }
}
