// lib/quran/quran_models.dart

class QuranAyah {
  final String verseKey; // e.g. "1:1"
  final String text;     // tajwid markup text

  const QuranAyah({
    required this.verseKey,
    required this.text,
  });
}

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameLatin;
  final List<QuranAyah> ayahs;

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameLatin,
    required this.ayahs,
  });

  String get label => '$number. $nameLatin • $nameArabic';
}