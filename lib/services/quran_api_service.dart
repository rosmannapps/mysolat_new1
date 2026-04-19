import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal chapter model
class QuranChapter {
  final int id;
  final String nameSimple; // e.g. "Al-Fatihah"
  final String nameArabic; // e.g. "الفاتحة"

  const QuranChapter({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
  });

  factory QuranChapter.fromJson(Map<String, dynamic> j) {
    return QuranChapter(
      id: j['id'] as int,
      nameSimple: (j['name_simple'] ?? '').toString(),
      nameArabic: (j['name_arabic'] ?? '').toString(),
    );
  }
}

/// One verse with tajweed markup + optional translation
class QuranVerse {
  final String verseKey; // e.g. "1:1"
  final String tajweed;  // HTML-like tajweed markup
  final String? translation;

  const QuranVerse({
    required this.verseKey,
    required this.tajweed,
    this.translation,
  });
}

class QuranApiService {
  QuranApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const String _base = 'https://api.quran.com/api/v4';

  /// Fetch chapter list for dropdown
  Future<List<QuranChapter>> fetchChapters() async {
    final uri = Uri.parse('$_base/chapters?language=en');
    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('Chapters API failed (${res.statusCode})');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final arr = (map['chapters'] as List).cast<dynamic>();

    return arr.map((e) => QuranChapter.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Fetch verses with tajweed + translations in ONE request.
  ///
  /// Uses the "by_chapter" endpoint and requests:
  /// - fields=text_uthmani_tajweed,verse_key
  /// - translations=<id> (e.g. 131 often used for Saheeh Intl in many examples)
  ///
  /// If translations are missing (API changes), Arabic still works.
  Future<List<QuranVerse>> fetchSurah({
    required int chapterNumber,
    int translationId = 131, // English default (can change later)
  }) async {
    final uri = Uri.parse('$_base/verses/by_chapter/$chapterNumber').replace(
      queryParameters: <String, String>{
        'words': 'false',
        'per_page': '300', // enough for any surah
        'fields': 'verse_key,text_uthmani_tajweed',
        'translations': translationId.toString(),
        'translation_fields': 'text',
      },
    );

    final res = await _client.get(uri).timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('Surah API failed (${res.statusCode})');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final verses = (map['verses'] as List).cast<dynamic>();

    return verses.map((v) {
      final j = v as Map<String, dynamic>;

      // Arabic tajweed markup
      final tajweed = (j['text_uthmani_tajweed'] ?? '').toString();

      // Translation (first translation in array, if present)
      String? translation;
      final trArr = j['translations'];
      if (trArr is List && trArr.isNotEmpty) {
        final first = trArr.first;
        if (first is Map<String, dynamic>) {
          translation = (first['text'] ?? '').toString();
        }
      }

      return QuranVerse(
        verseKey: (j['verse_key'] ?? '').toString(),
        tajweed: tajweed,
        translation: translation,
      );
    }).toList();
  }

  void dispose() {
    _client.close();
  }
}