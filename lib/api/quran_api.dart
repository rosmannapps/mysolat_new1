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
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'page_number': pageNumber.toString(),
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch Quran page $pageNumber. Status: ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Quran API response format.');
    }

    final versesRaw = decoded['verses'];

    if (versesRaw == null) {
      throw Exception(
        'Quran API response has no verses for page $pageNumber.',
      );
    }

    if (versesRaw is! List) {
      throw Exception('Quran verses data is not a list.');
    }

    return versesRaw.map<QuranVerse>((v) {
      if (v is! Map<String, dynamic>) {
        return QuranVerse(
          verseKey: '',
          text: '',
        );
      }

      final verseKey = v['verse_key']?.toString() ?? '';
      final text = v['text_uthmani_tajweed']?.toString() ?? '';

      return QuranVerse(
        verseKey: verseKey,
        text: text,
      );
    }).where((verse) => verse.text.trim().isNotEmpty).toList();
  }
}