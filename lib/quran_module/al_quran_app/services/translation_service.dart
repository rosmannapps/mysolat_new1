import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/translation_model.dart';

class TranslationService {
  static Future<List<VerseTranslation>> fetchTranslation({
    required int surahNumber,
    required int translationId,
  }) async {
    final url =
        'https://api.quran.com/api/v4/quran/translations/$translationId'
        '?chapter_number=$surahNumber';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to load translation');
    }

    final data = jsonDecode(response.body);

    final List verses = data['translations'];

    return verses
        .map((v) => VerseTranslation.fromJson(v))
        .toList();
  }
}