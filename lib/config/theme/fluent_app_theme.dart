import 'package:fluent_ui/fluent_ui.dart';
import 'package:system_theme/system_theme.dart';

class FluentAppTheme {
  static AccentColor get systemAccentColor {
    try {
      final accentColor = SystemTheme.accentColor.accent;
      return AccentColor.swatch({
        'darkest': accentColor,
        'darker': accentColor,
        'dark': accentColor,
        'normal': accentColor,
        'light': accentColor,
        'lighter': accentColor,
        'lightest': accentColor,
      });
    } catch (_) {
      return Colors.blue;
    }
  }

  static FluentThemeData lightTheme({AccentColor? accentColor}) {
    final accent = accentColor ?? systemAccentColor;
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: accent,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: const Color(0xFFF3F3F3),
      cardColor: Colors.white,
      typography: _typography(Brightness.light),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: const Color(0xFFF3F3F3),
        highlightColor: accent,
        iconPadding: const EdgeInsets.symmetric(horizontal: 10.0),
        labelPadding: const EdgeInsets.only(left: 8.0, right: 4.0),
      ),
      dialogTheme: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  static FluentThemeData darkTheme({AccentColor? accentColor}) {
    final accent = accentColor ?? systemAccentColor;
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: accent,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: const Color(0xFF202020),
      cardColor: const Color(0xFF2D2D2D),
      typography: _typography(Brightness.dark),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: const Color(0xFF202020),
        highlightColor: accent,
        iconPadding: const EdgeInsets.symmetric(horizontal: 10.0),
        labelPadding: const EdgeInsets.only(left: 8.0, right: 4.0),
      ),
      dialogTheme: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3D3D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  static Typography _typography(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textColor = isLight ? Colors.black : Colors.white;

    return Typography.raw(
      display: TextStyle(
        fontSize: 68,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI Variable Display',
      ),
      titleLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI Variable Display',
      ),
      title: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI Variable Display',
      ),
      subtitle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI Variable Text',
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.normal,
        color: textColor,
        fontFamily: 'Segoe UI Variable Text',
      ),
      bodyStrong: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI Variable Text',
      ),
      body: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textColor,
        fontFamily: 'Segoe UI Variable Text',
      ),
      caption: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textColor.withValues(alpha: 0.7),
        fontFamily: 'Segoe UI Variable Small',
      ),
    );
  }
}

// Extension to convert Color to AccentColor
extension ColorToAccentColor on Color {
  AccentColor toAccentColor() {
    return AccentColor.swatch({
      'darkest': withValues(alpha: 1.0),
      'darker': withValues(alpha: 0.9),
      'dark': withValues(alpha: 0.8),
      'normal': this,
      'light': withValues(alpha: 0.7),
      'lighter': withValues(alpha: 0.6),
      'lightest': withValues(alpha: 0.5),
    });
  }
}
