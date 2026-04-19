// lib/services/quran_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class QuranApiVerse {
  final String verseKey; // e.g. "1:1"
  final int verseNumber; // e.g. 1
  final String uthmaniTajweed; // contains <tajweed ...> markup
  final Map<int, String> translationsById; // translationId -> text

  QuranApiVerse({
    required this.verseKey,
    required this.verseNumber,
    required this.uthmaniTajweed,
    required this.translationsById,
  });
}

class QuranApi {
  static const String _base = 'https://api.quran.com/api/v4';

  /// Fetch a whole surah with tajwid markup + selected translation IDs.
  /// Uses pagination (max 50 per page).
  static Future<List<QuranApiVerse>> fetchSurah({
    required int chapterNumber,
    required List<int> translationIds,
  }) async {
    final verses = <QuranApiVerse>[];

    int page = 1;
    const int perPage = 50;

    while (true) {
      final uri = Uri.parse('$_base/verses/by_chapter/$chapterNumber').replace(
        queryParameters: {
          // NOTE: these are verse fields
          'fields': 'text_uthmani_tajweed,verse_key,verse_number',
          // NOTE: request translations
          'translations': translationIds.join(','),
          // translation object fields
          'translation_fields': 'text,resource_id,verse_key',
          'page': '$page',
          'per_page': '$perPage',
        },
      );

      final res = await http.get(uri);
      
      if (res.statusCode != 200) {
        throw Exception('API error ${res.statusCode}: ${res.body}');
      }

      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      final arr = (jsonMap['verses'] as List).cast<Map<String, dynamic>>();

      for (final v in arr) {
        final verseKey = (v['verse_key'] ?? '').toString();
        final verseNumber = (v['verse_number'] ?? 0) as int;
        final tajwid = (v['text_uthmani_tajweed'] ?? '').toString();

        final translations = <int, String>{};
        final tArr =
            (v['translations'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        for (final t in tArr) {
          final rid = (t['resource_id'] ?? 0) as int;

          // ✅ FIX: translation text key is "text"
          final rawText = (t['text'] ?? '').toString();

          translations[rid] = _stripBasicHtml(rawText);
        }

        verses.add(
          QuranApiVerse(
            verseKey: verseKey,
            verseNumber: verseNumber,
            uthmaniTajweed: tajwid,
            translationsById: translations,
          ),
        );
      }

      final pagination =
      (jsonMap['pagination'] as Map?)?.cast<String, dynamic>();
      final next = pagination?['next_page'];

      if (next == null) break;
      page = next is int ? next : int.tryParse(next.toString()) ?? (page + 1);
    }

    return verses;
  }

  /// Quran.com translations sometimes include HTML tags/entities.
  static String _stripBasicHtml(String input) {
    var s = input;

    // remove tags like <sup>, <i>, <b>, <span>, etc.
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');

    // basic HTML entities cleanup (enough for most quran.com translations)
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}