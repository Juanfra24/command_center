import 'package:fluent_ui/fluent_ui.dart';

/// Semantic color tokens for consistent status/state representation.
///
/// Provides theme-aware colors that meet contrast requirements in both
/// light and dark modes. Use `StatusColors.of(context)` to access.
///
/// Color mapping:
/// - [success] : running, active, healthy, created
/// - [error]   : banned, failed permanently, danger, delete
/// - [warning] : restarting, retrying, poor score, caution
/// - [info]    : awaiting, validating, in-progress
/// - [muted]   : stopped, inactive, unscored, disabled
/// - [fair]    : moderate score, acceptable but not ideal
class StatusColors {
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color muted;
  final Color fair;

  const StatusColors._({
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.muted,
    required this.fair,
  });

  /// Get theme-aware status colors based on current brightness.
  static StatusColors of(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  // -- Light mode: colors must meet >=4.5:1 on ~#F3F3F3 background --
  static const light = StatusColors._(
    success: Color(0xFF0F7B0F),
    error: Color(0xFFC42B1C),
    warning: Color(0xFF9D5D00),
    info: Color(0xFF0067C0),
    muted: Color(0xFF6E6E6E),
    fair: Color(0xFF7A6A00),
  );

  // -- Dark mode: lighter tones for >=4.5:1 on ~#202020/#2D2D2D --
  static const dark = StatusColors._(
    success: Color(0xFF6CCB5F),
    error: Color(0xFFFF99A4),
    warning: Color(0xFFFFB900),
    info: Color(0xFF60CDFF),
    muted: Color(0xFF9E9E9E),
    fair: Color(0xFFE8D44D),
  );

  /// Background tint for badges, containers, and chips.
  Color successBg([double alpha = 0.15]) => success.withValues(alpha: alpha);
  Color errorBg([double alpha = 0.15]) => error.withValues(alpha: alpha);
  Color warningBg([double alpha = 0.15]) => warning.withValues(alpha: alpha);
  Color infoBg([double alpha = 0.15]) => info.withValues(alpha: alpha);
  Color mutedBg([double alpha = 0.15]) => muted.withValues(alpha: alpha);
  Color fairBg([double alpha = 0.15]) => fair.withValues(alpha: alpha);
}
