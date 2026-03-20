import 'package:fluent_ui/fluent_ui.dart';
import 'package:command_center/core/widgets/toast_data.dart';

class ToastCard extends StatelessWidget {
  final ToastData toast;
  final VoidCallback onDismiss;

  const ToastCard({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final colors = _severityColors(theme);

    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(colors.icon, color: colors.foreground, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toast.title,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (toast.subtitle != null)
                  Text(
                    toast.subtitle!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 12),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  _SeverityColors _severityColors(FluentThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return switch (toast.severity) {
      ToastSeverity.success => _SeverityColors(
          background:
              isDark ? const Color(0xFF1e3a1e) : const Color(0xFFe8f5e9),
          border: isDark ? const Color(0xFF2d5a2d) : const Color(0xFF81c784),
          foreground:
              isDark ? const Color(0xFF4ade80) : const Color(0xFF2e7d32),
          icon: FluentIcons.completed,
        ),
      ToastSeverity.error => _SeverityColors(
          background:
              isDark ? const Color(0xFF3a1e1e) : const Color(0xFFffebee),
          border: isDark ? const Color(0xFF5a2d2d) : const Color(0xFFe57373),
          foreground:
              isDark ? const Color(0xFFf87171) : const Color(0xFFc62828),
          icon: FluentIcons.error_badge,
        ),
      ToastSeverity.warning => _SeverityColors(
          background:
              isDark ? const Color(0xFF3a2d1e) : const Color(0xFFFFF8E1),
          border: isDark ? const Color(0xFF5a4a2d) : const Color(0xFFFFD54F),
          foreground:
              isDark ? const Color(0xFFfbbf24) : const Color(0xFFf57f17),
          icon: FluentIcons.warning,
        ),
      ToastSeverity.info => _SeverityColors(
          background:
              isDark ? const Color(0xFF1e2d3a) : const Color(0xFFE3F2FD),
          border: isDark ? const Color(0xFF2d4a5a) : const Color(0xFF64B5F6),
          foreground:
              isDark ? const Color(0xFF60a5fa) : const Color(0xFF1565C0),
          icon: FluentIcons.info,
        ),
    };
  }
}

class _SeverityColors {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _SeverityColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });
}
