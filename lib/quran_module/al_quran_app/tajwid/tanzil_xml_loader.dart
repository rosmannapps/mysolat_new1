import 'package:flutter/services.dart' show rootBundle;

/// Loads Tanzil XML from assets and extracts:
/// - Surah number (index attribute)
/// - Ayah number (index attribute)
/// - Arabic text (text attribute)
///
/// Tanzil format example:
/// <sura index="1" name="...">
///   <aya index="1" text="بِسْمِ اللَّهِ ..." />
/// </sura>
class TanzilXmlLoader {
  static const String _assetPath = 'assets/quran/quran-uthmani.xml';

  /// Returns the ayah text (attribute "text") for given surah+ayah.
  static Future<String?> loadAyahText({
    required int surah,
    required int ayah,
  }) async {
    final xml = await rootBundle.loadString(_assetPath);

    // We avoid adding an XML package for now (fast + simple).
    // We locate the <sura index="X"...> ... </sura> block then find <aya index="Y" text="..."/>
    final suraOpen = '<sura index="$surah"';
    final suraStart = xml.indexOf(suraOpen);
    if (suraStart == -1) return null;

    final suraEnd = xml.indexOf('</sura>', suraStart);
    if (suraEnd == -1) return null;

    final suraBlock = xml.substring(suraStart, suraEnd);

    final ayaNeedle = '<aya index="$ayah"';
    final ayaStart = suraBlock.indexOf(ayaNeedle);
    if (ayaStart == -1) return null;

    // Find text="...":
    final textKey = 'text="';
    final textStart = suraBlock.indexOf(textKey, ayaStart);
    if (textStart == -1) return null;

    final textValueStart = textStart + textKey.length;
    final textValueEnd = suraBlock.indexOf('"', textValueStart);
    if (textValueEnd == -1) return null;

    final raw = suraBlock.substring(textValueStart, textValueEnd);

    // XML entities (rare in Arabic, but handle basics)
    return raw
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }
}