import '../../../services/prefs_service.dart';

class TranslationSettings {
  static const _keyTranslationId = 'translation_id';

  // Start with 2 languages (example IDs):
  // You will replace these IDs after you pick them from /resources/translations.
  static const int defaultMalayId = 33;
  static const int defaultEnglishId = 20;

  static Future<int> getTranslationId() async {
    final sp = PrefsService.instance;
    return sp.getInt(_keyTranslationId) ?? defaultEnglishId;
  }

  static Future<void> setTranslationId(int id) async {
    final sp = PrefsService.instance;
    await sp.setInt(_keyTranslationId, id);
  }
}