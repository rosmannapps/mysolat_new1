// lib/tajwid/local_surahs.dart
import 'fatihah_tajwid.dart';

class LocalSurah {
  final int number;
  final String latin;
  final String arabic;
  final List<Map<String, dynamic>> verses;

  const LocalSurah({
    required this.number,
    required this.latin,
    required this.arabic,
    required this.verses,
  });

  String get label => '$number. $latin • $arabic';
}

// ✅ Not const (so it won't complain if verses is not const)
final List<LocalSurah> kLocalSurahs = [
  LocalSurah(
    number: 1,
    latin: 'Al-Fatihah',
    arabic: 'الفاتحة',
    verses: fatihahTajwid, // ✅ matches your variable name
  ),
];