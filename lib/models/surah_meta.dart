// lib/models/surah_meta.dart
class SurahMeta {
  final int number;
  final String nameLatin;   // cleaned Latin name for UI
  final String nameArabic;
  final int ayahCount;

  const SurahMeta({
    required this.number,
    required this.nameLatin,
    required this.nameArabic,
    required this.ayahCount,
  });

  // Map extended transliteration letters to ASCII.
  static String _normalizeLatin(String s) {
    // 1) Replace common transliteration letters with ASCII
    const map = {
      'Ā': 'A', 'ā': 'a',
      'Ī': 'I', 'ī': 'i',
      'Ū': 'U', 'ū': 'u',
      'Ḥ': 'H', 'ḥ': 'h',
      'Ṣ': 'S', 'ṣ': 's',
      'Ṭ': 'T', 'ṭ': 't',
      'Ḍ': 'D', 'ḍ': 'd',
      'Ẓ': 'Z', 'ẓ': 'z',
      'ʿ': '',  // ayn -> drop for UI
      '’': "'", '‘': "'", 'ʼ': "'",
      // in case any weird macron combining slips through:
      '̄': '', // macron combining mark
    };

    final sb = StringBuffer();
    for (final cp in s.runes) {
      final ch = String.fromCharCode(cp);
      sb.write(map[ch] ?? ch);
    }
    var out = sb.toString();

    // 2) Strip remaining combining diacritics (Unicode Mn)
    out = out.replaceAll(RegExp(r'[\u0300-\u036f]'), '');

    // 3) Keep letters/digits/space/hyphen/apostrophe only
    out = out.replaceAll(RegExp(r"[^\w\s'-]"), '');

    // 4) Collapse spaces and trim
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

    return out;
    // Examples:
    //  "Āl ʿImrān"  -> "Al Imran"
    //  "Al-Mā’idah" -> "Al-Maidah"
  }

  factory SurahMeta.fromJson(Map<String, dynamic> j) {
    final rawNumber = j['number'] ?? j['no'] ?? j['id'] ?? 0;
    final rawLatin  = j['nameLatin'] ?? j['name_latin'] ?? j['latin'] ?? j['name'] ?? '';
    final rawArabic = j['nameArabic'] ?? j['name_arabic'] ?? j['arabic'] ?? '';
    final rawCount  = j['ayahCount'] ?? j['ayah_count'] ?? j['verses'] ?? 0;

    int parseInt(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

    return SurahMeta(
      number: parseInt(rawNumber),
      nameLatin: _normalizeLatin(rawLatin.toString()),
      nameArabic: rawArabic.toString(),
      ayahCount: parseInt(rawCount),
    );
  }
}