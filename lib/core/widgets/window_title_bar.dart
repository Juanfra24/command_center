import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

/// Custom title bar widget that provides window controls (minimize, maximize, close)
/// for a Windows-style application with hidden native title bar.
class WindowTitleBar extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const WindowTitleBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
    this.backgroundColor,
  });

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _updateMaximizedState() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted && isMaximized != _isMaximized) {
      setState(() => _isMaximized = isMaximized);
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final backgroundColor = widget.backgroundColor ??
        theme.navigationPaneTheme.backgroundColor ??
        theme.scaffoldBackgroundColor;

    return Container(
      height: 48,
      color: backgroundColor,
      child: Row(
        children: [
          // Draggable area for moving window
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    const SizedBox(width: 8),
                    widget.leading!,
                  ],
                  if (widget.title != null) ...[
                    const SizedBox(width: 12),
                    DefaultTextStyle(
                      style: theme.typography.caption!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      child: widget.title!,
                    ),
                  ],
                  const Spacer(),
                  if (widget.actions != null) ...widget.actions!,
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // Window control buttons
          _WindowControlButtons(isMaximized: _isMaximized),
        ],
      ),
    );
  }
}

class _WindowControlButtons extends StatelessWidget {
  final bool isMaximized;

  const _WindowControlButtons({required this.isMaximized});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: FluentIcons.chrome_minimize,
          tooltip: 'Minimize',
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: isMaximized
              ? FluentIcons.chrome_restore
              : FluentIcons.checkbox_fill,
          tooltip: isMaximized ? 'Restore' : 'Maximize',
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: FluentIcons.chrome_close,
          tooltip: 'Close',
          isCloseButton: true,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isCloseButton;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isCloseButton = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color iconColor;

    if (_isHovered) {
      if (widget.isCloseButton) {
        backgroundColor = Colors.red;
        iconColor = Colors.white;
      } else {
        backgroundColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        iconColor = isDark ? Colors.white : Colors.black;
      }
    } else {
      backgroundColor = Colors.transparent;
      iconColor = isDark ? Colors.white : Colors.black;
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 46,
            height: 48,
            color: backgroundColor,
            child: Center(
              child: Icon(
                widget.icon,
                size: 10,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
