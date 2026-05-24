// lib/services/quran_audio_service.dart
//
// Downloads the full-surah MP3 to device storage on first use,
// then plays from the local file — no network buffering during playback.
//
// Audio source : server11.mp3quran.net/sds/ (As-Sudais, full surah, same as
//                surahquran.com uses — smooth continuous recording)
// Timing source: api.qurancdn.com — verse_timings with ms timestamps
//                (reciter 2 = As-Sudais on Quran.com)

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

  // ── Audio source ──────────────────────────────────────────────────────────
  // Full surah MP3 by As-Sudais from mp3quran.net — same source as
  // surahquran.com. Single continuous recording = perfectly smooth.
  static String _audioUrl(int surahNumber) {
    final pad = surahNumber.toString().padLeft(3, '0');
    return 'https://server11.mp3quran.net/sds/$pad.mp3';
  }

  // ── Timing source ─────────────────────────────────────────────────────────
  // Quran.com CDN: reciter 2 = Abdurrahmaan as-Sudais (matches the audio above)
  // Falls back to reciter 7 (Abdul Basit) if 2 fails.
  static const List<int> _timingReciterIds = [2, 7, 4];
  static const String _timingApiBase =
      'https://api.qurancdn.com/api/qdc/audio/reciters';

  /// Prepare surah audio.
  ///
  /// 1. Fetch verse timing from Quran.com API (JSON only, fast).
  /// 2. Download the full-surah MP3 from mp3quran.net if not cached.
  /// 3. Return [SurahAudio] with local path + timings.
  ///
  /// [onProgress] receives 0.0 → 1.0 during the MP3 download.
  Future<SurahAudio> prepare(
    int surahNumber, {
    void Function(double progress)? onProgress,
  }) async {
    if (_cache.containsKey(surahNumber)) return _cache[surahNumber]!;

    // ── 1. Fetch verse timings ──────────────────────────────────────────────
    final timings = await _fetchTimings(surahNumber);

    // ── 2. Resolve local cache path ─────────────────────────────────────────
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio');
    await audioDir.create(recursive: true);

    final pad       = surahNumber.toString().padLeft(3, '0');
    final localPath = '${audioDir.path}/surah_${pad}_sudais.mp3';
    final localFile = File(localPath);

    // ── 3. Download if not cached ───────────────────────────────────────────
    if (!await localFile.exists()) {
      final url = _audioUrl(surahNumber);
      debugPrint('[QuranAudio] Downloading → $url');
      onProgress?.call(0.0);

      final request  = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
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

  // ── Timing fetch ──────────────────────────────────────────────────────────

  Future<List<AyahTiming>> _fetchTimings(int surahNumber) async {
    for (final reciterId in _timingReciterIds) {
      try {
        final url = Uri.parse(
          '$_timingApiBase/$reciterId/audio_files'
          '?chapter=$surahNumber&segments=true',
        );
        final res = await http
            .get(url, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;

        final data  = jsonDecode(res.body) as Map<String, dynamic>;
        final files = data['audio_files'] as List? ?? [];
        if (files.isEmpty) continue;

        final file       = files.first as Map<String, dynamic>;
        final rawTimings = file['verse_timings'] as List? ?? [];
        if (rawTimings.isEmpty) continue;

        final timings = <AyahTiming>[];
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

        if (timings.isNotEmpty) {
          timings.sort((a, b) => a.startMs.compareTo(b.startMs));
          debugPrint(
              '[QuranAudio] Timings loaded (reciter $reciterId): ${timings.length} ayahs');
          return timings;
        }
      } catch (e) {
        debugPrint('[QuranAudio] Timing fetch failed (reciter $reciterId): $e');
      }
    }
    debugPrint('[QuranAudio] No timing data available — verse scroll disabled');
    return [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the 0-based list index of the ayah at [positionMs].
  int ayahIndexAt(List<AyahTiming> timings, int positionMs) {
    for (int i = 0; i < timings.length; i++) {
      if (positionMs >= timings[i].startMs && positionMs < timings[i].endMs) {
        return i;
      }
    }
    if (positionMs > 0 && timings.isNotEmpty) return timings.length - 1;
    return 0;
  }

  // ── Per-ayah download ─────────────────────────────────────────────────────

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
        throw Exception('Download failed for ayah $ayahNo: ${res.statusCode}');
      }
    }
    return localPath;
  }

  // ── Timing-only fetch (no audio download) ────────────────────────────────

  /// Fetches verse timings without downloading the audio file.
  /// Useful for pre-loading timing data in the background.
  Future<List<AyahTiming>> fetchTimingsOnly(int surahNumber) =>
      _fetchTimings(surahNumber);

  // ── Cache management ──────────────────────────────────────────────────────

  Future<void> clearCache() async {
    _cache.clear();
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio');
    if (await audioDir.exists()) await audioDir.delete(recursive: true);
  }

  static int _asInt(dynamic v) {
    if (v == null)   return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
