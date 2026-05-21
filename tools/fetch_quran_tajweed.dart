import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  final output = <String, dynamic>{};

  for (int surah = 1; surah <= 114; surah++) {
    final verses = <Map<String, dynamic>>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_chapter/$surah'
            '?fields=text_uthmani_tajweed'
            '&per_page=50'
            '&page=$page',
      );

      stdout.writeln('Fetching surah $surah page $page...');

      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        stderr.writeln('Failed: ${response.statusCode}');
        stderr.writeln(body);
        exit(1);
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final list = (decoded['verses'] as List?) ?? [];

      for (final item in list) {
        final m = Map<String, dynamic>.from(item as Map);
        verses.add({
          'ayah': m['verse_number'],
          'verse_key': m['verse_key'],
          'arabic_tajweed': m['text_uthmani_tajweed'],
        });
      }

      final pagination = decoded['pagination'] as Map<String, dynamic>?;
      final currentPage = pagination?['current_page'] ?? page;
      final totalPages = pagination?['total_pages'] ?? page;

      if (currentPage >= totalPages) break;
      page++;
    }

    output[surah.toString()] = verses;
  }

  client.close(force: true);

  final dir = Directory('assets/tajwid');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final file = File('assets/tajwid/quran_tajweed.json');
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(output));

  stdout.writeln('DONE: assets/tajwid/quran_tajweed.json');
}