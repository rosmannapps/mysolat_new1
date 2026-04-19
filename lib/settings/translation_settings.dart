import 'package:shared_preferences/shared_preferences.dart';

class TranslationSettings {
  static const _keyTranslationId = 'translation_id';

  // Start with 2 languages (example IDs):
  // You will replace these IDs after you pick them from /resources/translations.
  static const int defaultMalayId = 33;
  static const int defaultEnglishId = 20;

  static Future<int> getTranslationId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_keyTranslationId) ?? defaultEnglishId;
  }

  static Future<void> setTranslationId(int id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_keyTranslationId, id);
  }
}