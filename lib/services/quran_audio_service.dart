// lib/services/quran_audio_service.dart
//
// Single-source-of-truth audio service.
//
// Uses ONE Quran Foundation API call per surah to get BOTH the audio URL
// and the verse timestamps — they are guaranteed to be in sync because they
// come from the same recording.
//
// Endpoint:
//   GET https://api.qurancdn.com/api/qdc/audio/reciters/2/audio_files
//       ?chapter={N}&segments=false
//
// Response shape (simplified):
//   {
//     "audio_files": [
//       {
//         "audio_url": "https://.../<reciter>/surah/.../<surah>.mp3",
//         "verse_timings": [
//           { "verse_key": "55:1", "timestamp_from": 0, "timestamp_to": 3210 },
//           ...
//         ]
//       }
//     ]
//   }
//
// Audio is cached locally as  quran_audio/surah_<NNN>_qf.mp3
// ("_qf" suffix distinguishes it from the old mp3quran.net cached files).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ── Data models ──────────────────────────────────────────────────────────────

class AyahTiming {
  final int ayahNumber; // 1-based ayah number within the surah
  final int startMs;
  final int endMs;

  const AyahTiming({
    required this.ayahNumber,
    required this.startMs,
    required this.endMs,
  });
}

class SurahAudio {
  /// Absolute path to the locally cached MP3 file.
  final String localPath;

  /// Per-ayah timestamps — may be empty if API is unreachable.
  final List<AyahTiming> timings;

  const SurahAudio({required this.localPath, required this.timings});
}

// ── Service ───────────────────────────────────────────────────────────────────

class QuranAudioService {
  QuranAudioService._();
  static final instance = QuranAudioService._();

  // In-memory cache: surahNumber → SurahAudio
  final _cache = <int, SurahAudio>{};

  // Quran Foundation API — reciter 3 = Abdurrahmaan As-Sudais
  // (quran.com/en/reciters/3 confirms this ID)
  static const int _reciterId = 3;
  static const String _apiBase =
      'https://api.qurancdn.com/api/qdc/audio/reciters';

  /// Prepare surah audio — single API call gets both URL and timings.
  ///
  /// 1. Call Quran Foundation API for chapter audio metadata.
  /// 2. Extract audio_url and verse_timings from the response.
  /// 3. Download the MP3 from audio_url if not already cached.
  /// 4. Return [SurahAudio] with local path + timings.
  ///
  /// [onProgress] receives 0.0 to 1.0 during the MP3 download.
  Future<SurahAudio> prepare(
    int surahNumber, {
    void Function(double progress)? onProgress,
  }) async {
    if (_cache.containsKey(surahNumber)) return _cache[surahNumber]!;

    // ── 1. Fetch metadata (audio URL + timings) ─────────────────────────────
    final meta = await _fetchMeta(surahNumber);
    final audioUrl = meta['audio_url'] as String;
    final timings  = meta['timings']   as List<AyahTiming>;

    // ── 2. Resolve local cache path ─────────────────────────────────────────
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio');
    await audioDir.create(recursive: true);

    final pad       = surahNumber.toString().padLeft(3, '0');
    // _sudais suffix = Quran Foundation reciter 3 (As-Sudais)
    // Different filename from old mp3quran.net cache to avoid stale playback.
    final localPath = '${audioDir.path}/surah_${pad}_sudais_qf.mp3';
    final localFile = File(localPath);

    // ── 3. Download if not cached ───────────────────────────────────────────
    if (!await localFile.exists()) {
      debugPrint('[QuranAudio] Downloading from QF → $audioUrl');
      onProgress?.call(0.0);

      final request  = http.Request('GET', Uri.parse(audioUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Audio download failed: HTTP ${response.statusCode}');
      }

      final total    = response.contentLength ?? 0;
      int   received = 0;
      final sink     = localFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }

      await sink.flush();
      await sink.close();
      onProgress?.call(1.0);
      debugPrint('[QuranAudio] Saved → $localPath');
    } else {
      debugPrint('[QuranAudio] Using cached → $localPath');
      onProgress?.call(1.0);
    }

    final result = SurahAudio(localPath: localPath, timings: timings);
    _cache[surahNumber] = result;
    return result;
  }

  // ── Metadata fetch ────────────────────────────────────────────────────────

  /// Returns a map with keys:
  ///   'audio_url' : String
  ///   'timings'   : List<AyahTiming>
  Future<Map<String, dynamic>> _fetchMeta(int surahNumber) async {
    final url = Uri.parse(
      '$_apiBase/$_reciterId/audio_files'
      '?chapter=$surahNumber&segments=false',
    );

    debugPrint('[QuranAudio] Fetching meta → $url');

    final res = await http
        .get(url, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Meta fetch failed: HTTP ${res.statusCode}');
    }

    final data  = jsonDecode(res.body) as Map<String, dynamic>;

    // The API returns either "audio_files" (list) or "audio_file" (object).
    Map<String, dynamic>? file;
    if (data['audio_files'] is List && (data['audio_files'] as List).isNotEmpty) {
      file = (data['audio_files'] as List).first as Map<String, dynamic>;
    } else if (data['audio_file'] is Map) {
      file = data['audio_file'] as Map<String, dynamic>;
    }

    if (file == null) {
      throw Exception('No audio_file in API response for surah $surahNumber');
    }

    // ── audio URL ────────────────────────────────────────────────────────────
    final rawUrl = (file['audio_url'] ?? '').toString().trim();
    if (rawUrl.isEmpty) {
      throw Exception('Empty audio_url in API response for surah $surahNumber');
    }
    // The API sometimes returns a relative URL — make it absolute.
    final audioUrl = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://verses.quran.com/$rawUrl';

    // ── verse timings ────────────────────────────────────────────────────────
    final rawTimings = file['verse_timings'] as List? ?? [];
    final timings    = <AyahTiming>[];

    for (final t in rawTimings) {
      if (t is! Map) continue;
      final key     = (t['verse_key'] ?? '').toString();
      final startMs = _asInt(t['timestamp_from']);
      final endMs   = _asInt(t['timestamp_to']);
      if (key.isEmpty || endMs <= startMs) continue;
      final parts   = key.split(':');
      final ayahNum = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
      if (ayahNum <= 0) continue;
      timings.add(AyahTiming(
        ayahNumber: ayahNum,
        startMs:    startMs,
        endMs:      endMs,
      ));
    }

    timings.sort((a, b) => a.startMs.compareTo(b.startMs));
    debugPrint(
        '[QuranAudio] Meta loaded: ${timings.length} timings, url=$audioUrl');

    return {'audio_url': audioUrl, 'timings': timings};
  }

  // ── Timing-only fetch (no audio download) ────────────────────────────────

  /// Fetches verse timings without downloading the audio file.
  /// Useful for pre-loading timing data in the background.
  Future<List<AyahTiming>> fetchTimingsOnly(int surahNumber) async {
    try {
      final meta = await _fetchMeta(surahNumber);
      return meta['timings'] as List<AyahTiming>;
    } catch (e) {
      debugPrint('[QuranAudio] fetchTimingsOnly failed: $e');
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the 0-based list index of the ayah playing at [positionMs].
  int ayahIndexAt(List<AyahTiming> timings, int positionMs) {
    if (timings.isEmpty) return 0;
    // Binary search for efficiency
    int lo = 0, hi = timings.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (positionMs < timings[mid].startMs) {
        hi = mid - 1;
      } else if (positionMs >= timings[mid].endMs) {
        lo = mid + 1;
      } else {
        return mid; // found
      }
    }
    // positionMs is beyond the last timing or before the first
    if (positionMs >= timings.last.endMs) return timings.length - 1;
    return 0;
  }

  // ── Per-ayah download (for individual ayah play buttons) ─────────────────

  Future<String> ayahLocalPath(int surahNo, int ayahNo) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio/ayah');
    await audioDir.create(recursive: true);
    final s = surahNo.toString().padLeft(3, '0');
    final a = ayahNo.toString().padLeft(3, '0');
    return '${audioDir.path}/${s}_$a.mp3';
  }

  Future<bool> isAyahCached(int surahNo, int ayahNo) async {
    final path = await ayahLocalPath(surahNo, ayahNo);
    return File(path).exists();
  }

  Future<void> downloadPerAyah({
    required int surahNumber,
    required int ayahCount,
    void Function(int completedCount)? onProgress,
  }) async {
    for (int i = 1; i <= ayahCount; i++) {
      final localPath = await ayahLocalPath(surahNumber, i);
      final file      = File(localPath);
      if (!await file.exists()) {
        final s   = surahNumber.toString().padLeft(3, '0');
        final a   = i.toString().padLeft(3, '0');
        final url =
            'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/$s$a.mp3';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) await file.writeAsBytes(res.bodyBytes);
      }
      onProgress?.call(i);
    }
  }

  Future<String> prepareAyah(int surahNo, int ayahNo) async {
    final localPath = await ayahLocalPath(surahNo, ayahNo);
    final file      = File(localPath);
    if (!await file.exists()) {
      final s   = surahNo.toString().padLeft(3, '0');
      final a   = ayahNo.toString().padLeft(3, '0');
      final url =
          'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps/$s$a.mp3';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        await file.writeAsBytes(res.bodyBytes);
      } else {
        throw Exception(
            'Per-ayah download failed for $surahNo:$ayahNo — HTTP ${res.statusCode}');
      }
    }
    return localPath;
  }

  // ── Cache management ──────────────────────────────────────────────────────

  Future<void> clearCache() async {
    _cache.clear();
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio');
    if (await audioDir.exists()) await audioDir.delete(recursive: true);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static int _asInt(dynamic v) {
    if (v == null)   return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
