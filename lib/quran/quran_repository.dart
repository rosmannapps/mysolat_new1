// lib/quran/quran_repository.dart
import 'package:flutter/services.dart' show rootBundle;

import 'quran_models.dart';

class QuranRepository {
  QuranRepository._();
  static final QuranRepository instance = QuranRepository._();

  List<QuranSurah>? _cache;

  Future<List<QuranSurah>> loadFromAssets() async {
    if (_cache != null) return _cache!;

    const path = 'assets/quran/quran-uthmani.cpfair.txt';
    final raw = await rootBundle.loadString(path);

    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final map = <int, List<QuranAyah>>{};

    for (final line in lines) {
      // Format: TEXT|ayah|surah
      final parts = line.split('|');
      if (parts.length != 3) continue;

      final text = parts[0].trim();
      final ayah = int.tryParse(parts[1]);
      final surah = int.tryParse(parts[2]);

      if (surah == null || ayah == null) continue;

      final withEnd =
          '$text <span class=end>${_toArabicDigits(ayah)}</span>';

      (map[surah] ??= []).add(QuranAyah(
        verseKey: '$surah:$ayah',
        text: withEnd,
      ));
    }

    final surahs = <QuranSurah>[];

    for (int s = 1; s <= 114; s++) {
      final ayahs = map[s] ?? <QuranAyah>[];
      surahs.add(QuranSurah(
        number: s,
        nameArabic: '',
        nameLatin: 'Surah $s',
        ayahs: ayahs,
      ));
    }

    _cache = surahs;
    return surahs;
  }

  String _toArabicDigits(int n) {
    const map = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };
    return n.toString().split('').map((c) => map[c] ?? c).join();
  }
}