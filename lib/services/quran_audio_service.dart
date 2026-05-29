// lib/services/quran_audio_service.dart
//
// Single-source-of-truth audio service.
//
// Uses the Quran Foundation API to get BOTH the full-surah audio URL
// and verse timestamps for the selected reciter.
//
// Per-ayah streaming uses everyayah.com (faster, no download needed).
//
// Endpoint:
//   GET https://api.qurancdn.com/api/qdc/audio/reciters/{id}/audio_files
//       ?chapter={N}&segments=false
//

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Reciter model ─────────────────────────────────────────────────────────────

class QuranReciter {
  final int    id;                // Internal app ID (1–5)
  final String name;              // English display name
  final String nameAr;            // Arabic name
  final String origin;            // Country / mosque
  final String style;             // Murattal / Mujawwad
  final String everyayahFolder;   // Folder name on everyayah.com
  final int    qfApiId;           // Quran Foundation API reciter ID
  final String fileSuffix;        // Suffix for local cache filename

  const QuranReciter({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.origin,
    required this.style,
    required this.everyayahFolder,
    required this.qfApiId,
    required this.fileSuffix,
  });
}

// ── Top-5 reciter catalogue ────────────────────────────────────────────────────

const List<QuranReciter> kQuranReciters = [
  QuranReciter(
    id: 1,
    name: 'Abdurrahman As-Sudais',
    nameAr: 'عبد الرحمن السديس',
    origin: 'Masjid Al-Haram, Mecca',
    style: 'Murattal',
    everyayahFolder: 'Abdurrahmaan_As-Sudais_192kbps',
    qfApiId: 3,
    fileSuffix: 'sudais',
  ),
  QuranReciter(
    id: 2,
    name: 'Mishary Rashid Alafasy',
    nameAr: 'مشاري راشد العفاسي',
    origin: 'Kuwait',
    style: 'Murattal',
    everyayahFolder: 'Alafasy_128kbps',
    qfApiId: 7,
    fileSuffix: 'alafasy',
  ),
  QuranReciter(
    id: 3,
    name: 'Maher Al-Muaiqly',
    nameAr: 'ماهر المعيقلي',
    origin: 'Masjid Al-Haram, Mecca',
    style: 'Murattal',
    everyayahFolder: 'MaherAlMuaiqly128kbps',
    qfApiId: 9,
    fileSuffix: 'maher',
  ),
  QuranReciter(
    id: 4,
    name: 'Saad Al-Ghamdi',
    nameAr: 'سعد الغامدي',
    origin: 'Saudi Arabia',
    style: 'Murattal',
    everyayahFolder: 'Ghamadi_40kbps',
    qfApiId: 11,
    fileSuffix: 'ghamdi',
  ),
  QuranReciter(
    id: 5,
    name: 'Abu Bakr Al-Shatri',
    nameAr: 'أبو بكر الشاطري',
    origin: 'Saudi Arabia',
    style: 'Murattal',
    everyayahFolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
    qfApiId: 12,
    fileSuffix: 'shatri',
  ),
];

// ── Data models ───────────────────────────────────────────────────────────────

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

  // In-memory cache: surahNumber → SurahAudio  (keyed per reciter via clear on change)
  final _cache = <int, SurahAudio>{};

  static const String _apiBase          = 'https://api.qurancdn.com/api/qdc/audio/reciters';
  static const String _prefKeyReciterId = 'quran_selected_reciter_id';

  QuranReciter _selectedReciter = kQuranReciters.first; // default = As-Sudais
  QuranReciter get selectedReciter => _selectedReciter;

  // ── Reciter management ────────────────────────────────────────────────────

  /// Load the user's saved reciter preference from SharedPreferences.
  /// Call this once at app start (or lazily before first use).
  Future<void> loadSavedReciter() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(_prefKeyReciterId) ?? 1;
      _selectedReciter = kQuranReciters.firstWhere(
        (r) => r.id == savedId,
        orElse: () => kQuranReciters.first,
      );
      debugPrint('[QuranAudio] Loaded reciter: ${_selectedReciter.name}');
    } catch (e) {
      debugPrint('[QuranAudio] loadSavedReciter error: $e');
    }
  }

  /// Change the active reciter and persist the choice.
  /// Clears the in-memory cache so the next prepare() re-downloads for the new reciter.
  Future<void> setReciter(QuranReciter reciter) async {
    if (_selectedReciter.id == reciter.id) return;
    _selectedReciter = reciter;
    _cache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyReciterId, reciter.id);
      debugPrint('[QuranAudio] Reciter changed to: ${reciter.name}');
    } catch (e) {
      debugPrint('[QuranAudio] setReciter save error: $e');
    }
  }

  // ── Per-ayah URL helper ───────────────────────────────────────────────────

  /// Returns the everyayah.com streaming URL for one ayah using the selected reciter.
  String everyayahUrl(int surahNo, int ayahNo) {
    final s = surahNo.toString().padLeft(3, '0');
    final a = ayahNo.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/${_selectedReciter.everyayahFolder}/$s$a.mp3';
  }

  // ── Full-surah prepare (download + timings) ───────────────────────────────

  /// Prepare surah audio — uses the currently selected reciter.
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

    final reciter = _selectedReciter;

    // ── 1. Fetch metadata (audio URL + timings) ─────────────────────────────
    final meta     = await _fetchMeta(surahNumber, reciter.qfApiId);
    final audioUrl = meta['audio_url'] as String;
    final timings  = meta['timings']   as List<AyahTiming>;

    // ── 2. Resolve local cache path ─────────────────────────────────────────
    final cacheDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${cacheDir.path}/quran_audio');
    await audioDir.create(recursive: true);

    final pad       = surahNumber.toString().padLeft(3, '0');
    final localPath = '${audioDir.path}/surah_${pad}_${reciter.fileSuffix}_qf.mp3';
    final localFile = File(localPath);

    // ── 3. Download if not cached ───────────────────────────────────────────
    if (!await localFile.exists()) {
      debugPrint('[QuranAudio] Downloading [${reciter.name}] → $audioUrl');
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

  Future<Map<String, dynamic>> _fetchMeta(int surahNumber, int reciterId) async {
    final url = Uri.parse(
      '$_apiBase/$reciterId/audio_files'
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

    Map<String, dynamic>? file;
    if (data['audio_files'] is List && (data['audio_files'] as List).isNotEmpty) {
      file = (data['audio_files'] as List).first as Map<String, dynamic>;
    } else if (data['audio_file'] is Map) {
      file = data['audio_file'] as Map<String, dynamic>;
    }

    if (file == null) {
      throw Exception('No audio_file in API response for surah $surahNumber');
    }

    final rawUrl = (file['audio_url'] ?? '').toString().trim();
    if (rawUrl.isEmpty) {
      throw Exception('Empty audio_url in API response for surah $surahNumber');
    }
    final audioUrl = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://verses.quran.com/$rawUrl';

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
    debugPrint('[QuranAudio] Meta loaded: ${timings.length} timings, url=$audioUrl');

    return {'audio_url': audioUrl, 'timings': timings};
  }

  // ── Timing-only fetch (no audio download) ────────────────────────────────

  Future<List<AyahTiming>> fetchTimingsOnly(int surahNumber) async {
    try {
      final meta = await _fetchMeta(surahNumber, _selectedReciter.qfApiId);
      return meta['timings'] as List<AyahTiming>;
    } catch (e) {
      debugPrint('[QuranAudio] fetchTimingsOnly failed: $e');
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int ayahIndexAt(List<AyahTiming> timings, int positionMs) {
    if (timings.isEmpty) return 0;
    int lo = 0, hi = timings.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (positionMs < timings[mid].startMs) {
        hi = mid - 1;
      } else if (positionMs >= timings[mid].endMs) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
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
    return '${audioDir.path}/${s}_${a}_${_selectedReciter.fileSuffix}.mp3';
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
    final reciter = _selectedReciter;
    for (int i = 1; i <= ayahCount; i++) {
      final localPath = await ayahLocalPath(surahNumber, i);
      final file      = File(localPath);
      if (!await file.exists()) {
        final s   = surahNumber.toString().padLeft(3, '0');
        final a   = i.toString().padLeft(3, '0');
        final url = 'https://everyayah.com/data/${reciter.everyayahFolder}/$s$a.mp3';
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
      final url = everyayahUrl(surahNo, ayahNo);
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

  static int _asInt(dynamic v) {
    if (v == null)   return 0;
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
