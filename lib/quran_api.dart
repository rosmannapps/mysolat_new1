// lib/quran_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class QuranVerse {
  final String verseKey;
  final String text;

  QuranVerse({
    required this.verseKey,
    required this.text,
  });
}

class QuranApi {
  static const String baseUrl =
      'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed';

  static Future<List<QuranVerse>> fetchPage(int pageNumber) async {
    final uri = Uri.parse('$baseUrl?page_number=$pageNumber');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch page $pageNumber');
    }

    final data = json.decode(response.body);
    final versesJson = data['verses'] as List;

    return versesJson
        .map((v) => QuranVerse(
      verseKey: v['verse_key'] as String,
      text: v['text_uthmani_tajweed'] as String,
    ))
        .toList();
  }
}