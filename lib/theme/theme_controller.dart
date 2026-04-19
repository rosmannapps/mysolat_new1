import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.teal,
      useMaterial3: true,
    );
  }

  ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.teal,
      useMaterial3: true,
    );
  }

  String themeModeLabel() {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
    // No default: needed because all enum values are covered.
  }
}