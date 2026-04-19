// lib/models/quran_models.dart
class SurahMeta {
  final int id;
  final String nameArabic;
  final String nameLatin;
  final String revelationPlace; // "Mecca" | "Medina"
  final int ayahCount;

  const SurahMeta({
    required this.id,
    required this.nameArabic,
    required this.nameLatin,
    required this.revelationPlace,
    required this.ayahCount,
  });

  factory SurahMeta.fromJson(Map<String, dynamic> m) => SurahMeta(
    id: m['id'] as int,
    nameArabic: m['nameArabic'] as String,
    nameLatin: m['nameLatin'] as String,
    revelationPlace: m['revelationPlace'] as String,
    ayahCount: m['ayahCount'] as int,
  );
}

class SurahAyah {
  final int ayah;
  final String arabic;
  final String malay;

  const SurahAyah({
    required this.ayah,
    required this.arabic,
    required this.malay,
  });

  factory SurahAyah.fromJson(Map<String, dynamic> m) => SurahAyah(
    ayah: (m['ayah'] as num).toInt(),
    arabic: (m['arabic'] ?? '') as String,
    malay: (m['malay'] ?? '') as String,
  );
}