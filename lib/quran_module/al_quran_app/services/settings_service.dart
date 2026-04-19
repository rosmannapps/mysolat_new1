import '../../../services/prefs_service.dart';

class SettingsService {
  static const _keyLanguage = 'translation_language';

  static Future<void> setLanguage(String code) async {
    final prefs = PrefsService.instance;
    await prefs.setString(_keyLanguage, code);
  }

  static Future<String> getLanguage() async {
    final prefs = PrefsService.instance;
    return prefs.getString(_keyLanguage) ?? 'en';
  }
}