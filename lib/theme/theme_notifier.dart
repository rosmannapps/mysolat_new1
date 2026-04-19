import 'package:flutter/material.dart';
import '../services/quran_prefs.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final v = await QuranPrefs.getDarkMode(); // null=system, true=dark, false=light
    _mode = v == null ? ThemeMode.system : (v ? ThemeMode.dark : ThemeMode.light);
    notifyListeners();
  }

  Future<void> toggle() async {
    // Cycle: light → dark → system → light …
    if (_mode == ThemeMode.light) {
      _mode = ThemeMode.dark;
      await QuranPrefs.setDarkMode(true);
    } else if (_mode == ThemeMode.dark) {
      _mode = ThemeMode.system;
      await QuranPrefs.setDarkMode(null);
    } else {
      _mode = ThemeMode.light;
      await QuranPrefs.setDarkMode(false);
    }
    notifyListeners();
  }
}