// lib/models/surah_ayah.dart
class SurahAyah {
  // Your "real" internal fields
  final int n;        // ayah number
  final String a;     // Arabic text
  final String ms;    // Malay translation

  const SurahAyah({
    required this.n,
    required this.a,
    required this.ms,
  });

  // --- Compatibility getters for older code / repo ---
  // The repo is trying to read `ayah`, `arabic`, `malay`.
  int get ayah => n;
  String get arabic => a;
  String get malay => ms;

  // Also sometimes older code uses `ar` instead of `a`.
  // We don't expose a separate field, but fromJson will accept both.

  factory SurahAyah.fromJson(Map<String, dynamic> j) {
    // Accept multiple field spellings from different data sources.
    dynamic _pick(List<String> keys) {
      for (final k in keys) {
        if (j.containsKey(k) && j[k] != null) return j[k];
      }
      return null;
    }

    final rawNum = _pick(['n', 'num', 'ayah', 'index']) ?? 0;
    final rawAr  = _pick(['a', 'ar', 'arabic', 'text_ar']) ?? '';
    final rawMs  = _pick(['ms', 'malay', 'translation_ms', 'text_ms']) ?? '';

    int parseInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

    return SurahAyah(
      n:  parseInt(rawNum),
      a:  rawAr.toString(),
      ms: rawMs.toString(),
    );
  }
}