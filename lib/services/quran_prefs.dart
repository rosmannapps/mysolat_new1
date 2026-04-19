import 'package:mysolat/services/prefs_service.dart';

class QuranPrefs {
  static const _kArSize = 'q_ar_size';
  static const _kMsSize = 'q_ms_size';
  static const _kShowTr = 'q_show_tr';
  static const _kLastSurah = 'q_last_surah';
  static const _kLastAyah = 'q_last_ayah';
  static const _kDarkMode = 'q_dark_mode'; // bool? (null = system)
  static String _kScrollKey(int surah) => 'q_scroll_$surah';

  // Font sizes
  static Future<double> getArabicFontSize() async =>
      PrefsService.instance.getDouble(_kArSize) ?? 26.0;
  static Future<void> setArabicFontSize(double v) async =>
      PrefsService.instance.setDouble(_kArSize, v);

  static Future<double> getMalayFontSize() async =>
      PrefsService.instance.getDouble(_kMsSize) ?? 16.0;
  static Future<void> setMalayFontSize(double v) async =>
      PrefsService.instance.setDouble(_kMsSize, v);

  // Show translation
  static Future<bool> getShowTranslation() async =>
      PrefsService.instance.getBool(_kShowTr) ?? true;
  static Future<void> setShowTranslation(bool v) async =>
      PrefsService.instance.setBool(_kShowTr, v);

  // Last read
  static Future<void> saveLastRead(int surah, int ayah) async {
    final sp = PrefsService.instance;
    await sp.setInt(_kLastSurah, surah);
    await sp.setInt(_kLastAyah, ayah);
  }

  static Future<(int?, int?)> getLastRead() async {
    final sp = PrefsService.instance;
    return (sp.getInt(_kLastSurah), sp.getInt(_kLastAyah));
  }

  // Theme (null = system, true = dark, false = light)
  static Future<bool?> getDarkMode() async {
    final sp = PrefsService.instance;
    return sp.containsKey(_kDarkMode) ? sp.getBool(_kDarkMode) : null;
  }
  static Future<void> setDarkMode(bool? isDark) async {
    final sp = PrefsService.instance;
    if (isDark == null) {
      await sp.remove(_kDarkMode);
    } else {
      await sp.setBool(_kDarkMode, isDark);
    }
  }

  // Scroll position (per-surah)
  static Future<double> getScrollOffset(int surah) async =>
      PrefsService.instance.getDouble(_kScrollKey(surah)) ?? 0.0;

  static Future<void> setScrollOffset(int surah, double offset) async =>
      PrefsService.instance.setDouble(_kScrollKey(surah), offset.clamp(0.0, 1e9));
}