import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

class QuranAyah {
  final int index; // number in surah
  final String text;

  QuranAyah({required this.index, required this.text});
}

class QuranSurah {
  final int index; // surah number
  final String nameArabic;
  final List<QuranAyah> ayat;

  QuranSurah({
    required this.index,
    required this.nameArabic,
    required this.ayat,
  });
}

class QuranLoader {
  // ✅ must match pubspec.yaml
  static const String _assetPath = 'assets/quran/quran-uthmani.xml';

  static Future<QuranSurah> loadSurah(int surahIndex) async {
    final raw = await rootBundle.loadString(_assetPath);
    final doc = XmlDocument.parse(raw);

    // <quran> -> <sura index="1" name="..."> -> <aya index="1" text="..." />
    final sura = doc
        .findAllElements('sura')
        .firstWhere((e) => e.getAttribute('index') == surahIndex.toString());

    final name = sura.getAttribute('name') ?? '';

    final ayat = sura.findElements('aya').map((ayaEl) {
      final idxStr = ayaEl.getAttribute('index') ?? '0';
      final txt = ayaEl.getAttribute('text') ?? '';
      return QuranAyah(
        index: int.tryParse(idxStr) ?? 0,
        text: txt,
      );
    }).toList();

    return QuranSurah(
      index: surahIndex,
      nameArabic: name,
      ayat: ayat,
    );
  }
}