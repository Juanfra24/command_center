import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/config/theme/theme_manager.dart';
import 'package:command_center/core/widgets/window_title_bar.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:command_center/feature/notification/controller/notification_controller.dart';
import 'package:command_center/feature/notification/views/components/notification_bell.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

/// Title bar for the app shell with menu toggle, music toggle, theme toggle,
/// and notification bell.
class AppTitleBar extends StatelessWidget {
  final PaneDisplayMode paneDisplayMode;
  final VoidCallback onTogglePane;
  final FlyoutController flyoutController;
  final MusicController? musicController;
  final NotificationService? notificationService;
  final NotificationController? notificationController;
  final bool isDark;

  const AppTitleBar({
    super.key,
    required this.paneDisplayMode,
    required this.onTogglePane,
    required this.flyoutController,
    this.musicController,
    this.notificationService,
    this.notificationController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return WindowTitleBar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              paneDisplayMode == PaneDisplayMode.open
                  ? FluentIcons.collapse_menu
                  : FluentIcons.expand_menu,
              size: 16,
            ),
            onPressed: onTogglePane,
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/runescape_icon.png',
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(FluentIcons.game, size: 20),
          ),
        ],
      ),
      title: const Text('RuneScape Bot Command Center'),
      actions: [
        if (notificationService != null && notificationController != null)
          NotificationBell(
            flyoutController: flyoutController,
            notificationService: notificationService!,
            notificationController: notificationController!,
          ),
        const SizedBox(width: 8),
        _buildMusicButton(),
        const SizedBox(width: 8),
        _buildThemeToggle(),
      ],
    );
  }

  Widget _buildMusicButton() {
    final mc = musicController;
    if (mc == null) return const SizedBox.shrink();
    return Obx(() => IconButton(
          icon: Icon(
            mc.isPlaying.value
                ? FluentIcons.music_in_collection_fill
                : FluentIcons.music_note,
          ),
          onPressed: () {
            if (mc.isPlaying.value) {
              mc.pauseAudio();
            } else {
              mc.playAudio();
            }
          },
        ));
  }

  Widget _buildThemeToggle() {
    return ToggleSwitch(
      checked: isDark,
      onChanged: (value) {
        ThemeManage.changeThemeMode();
      },
      content: Row(
        children: [
          Icon(isDark ? FluentIcons.clear_night : FluentIcons.sunny),
          const SizedBox(width: 8),
          Text(isDark ? 'Dark' : 'Light'),
        ],
      ),
    );
  }
}
