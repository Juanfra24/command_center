import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

import '../../core/resource/local_storage/local_storage.dart';

class ThemeManage {
  ThemeManage._(); // Prevent instantiation

  static const _themeKey = "isDarkMode";

  static final Rx<ThemeMode> _themeMode = getThemeMode().obs;

  static ThemeMode get currentThemeMode => _themeMode.value;

  static bool isDarkModeActive() {
    var isDarkModeActive = LocalStorage.get(key: _themeKey);
    if (isDarkModeActive == null) {
      isDarkModeActive = true; // Default to dark mode for modern Windows feel
      LocalStorage.set(key: _themeKey, value: isDarkModeActive);
    }
    return isDarkModeActive;
  }

  static ThemeMode getThemeMode() {
    return isDarkModeActive() ? ThemeMode.dark : ThemeMode.light;
  }

  static void _saveThemeMode(bool isDarkMode) {
    LocalStorage.set(key: _themeKey, value: isDarkMode);
  }

  static void changeThemeMode() {
    final newMode = isDarkModeActive() ? ThemeMode.light : ThemeMode.dark;
    _themeMode.value = newMode;
    _saveThemeMode(!isDarkModeActive());
  }

}
