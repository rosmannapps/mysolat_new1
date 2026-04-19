import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStore {
  static const _kTranslation = 'translation_lang';
  static const _kArabicFontSize = 'arabic_font_size';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final langStr = prefs.getString(_kTranslation) ?? 'ms';
    final size = prefs.getDouble(_kArabicFontSize) ?? AppSettings.defaults.arabicFontSize;

    final lang = TranslationLang.values.firstWhere(
          (e) => e.name == langStr,
      orElse: () => AppSettings.defaults.translation,
    );

    return AppSettings(
      translation: lang,
      arabicFontSize: size,
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTranslation, s.translation.name);
    await prefs.setDouble(_kArabicFontSize, s.arabicFontSize);
  }
}