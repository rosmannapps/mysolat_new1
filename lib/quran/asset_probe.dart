import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AssetProbe {
  static Future<String> probe() async {
    final lines = <String>[];

    final manifestStr = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest =
    (jsonDecode(manifestStr) as Map).cast<String, dynamic>();

    final keys = manifest.keys.toList()..sort();

    lines.add('Manifest keys count: ${keys.length}');
    lines.add('Has txt key: ${keys.contains("assets/quran/quran-uthmani.cpfair.txt")}');
    lines.add('--- keys containing "quran-uthmani" ---');
    for (final k in keys.where((k) => k.contains('quran-uthmani'))) {
      lines.add(k);
    }

    Future<void> tryLoad(String path) async {
      try {
        final data = await rootBundle.load(path);
        lines.add('LOAD OK: $path bytes=${data.lengthInBytes}');
      } catch (e) {
        lines.add('LOAD FAIL: $path error=$e');
      }
    }

    lines.add('--- Direct load test ---');
    await tryLoad('assets/quran/quran-uthmani.cpfair.txt');

    return lines.join('\n');
  }
}