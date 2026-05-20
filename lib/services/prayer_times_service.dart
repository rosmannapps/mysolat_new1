// lib/services/prayer_times_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';
import '../models/monthly_prayer_entry.dart';
import 'aladhan_service.dart';
import 'jakim_http.dart';

class PrayerTimesService {
  PrayerTimesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String sabahNoRecordMessage =
      'Prayer times are sourced from official JAKIM e-Solat API.\n'
      'Sabah data is temporarily unavailable from the source.';

  static const Duration _timeout = Duration(seconds: 30);

  // ===================== CACHE (DAY) =====================

  static const String _cachePrefixDay = 'pt_day_v1';
  static const String _yearMetaPrefix = 'pt_year_meta_v1';
  static const String _freshnessPrefix = 'pt_freshness_v1';

  static const Duration _staleThreshold = Duration(days: 7);
  static const Duration _yearRefreshCooldown = Duration(days: 14);
  static const Duration _cacheRetention = Duration(days: 60);
  static const Duration _interMonthDelay = Duration(milliseconds: 600);

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  String _dayCacheKey(String zoneCode, DateTime date) =>
      '$_cachePrefixDay:${zoneCode.toUpperCase()}:${_ymd(date)}';

  String _yearMetaKey(String zoneCode, int year) =>
      '$_yearMetaPrefix:${zoneCode.toUpperCase()}:$year';

  String _freshnessKey(String zoneCode) =>
      '$_freshnessPrefix:${zoneCode.toUpperCase()}';

  Map<String, dynamic> _ptToJson(PrayerTimes t) => <String, dynamic>{
    'subuh': t.subuh,
    'syuruk': t.syuruk,
    'zohor': t.zohor,
    'asar': t.asar,
    'maghrib': t.maghrib,
    'isyak': t.isyak,
    'hijri': t.hijri,
  };

  PrayerTimes _ptFromJson(Map<String, dynamic> json) => PrayerTimes(
    subuh: (json['subuh'] ?? '').toString(),
    syuruk: (json['syuruk'] ?? '').toString(),
    zohor: (json['zohor'] ?? '').toString(),
    asar: (json['asar'] ?? '').toString(),
    maghrib: (json['maghrib'] ?? '').toString(),
    isyak: (json['isyak'] ?? '').toString(),
    hijri: (json['hijri'] ?? '').toString(),
  );

  Future<PrayerTimes?> readCachedDay(String zoneCode, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dayCacheKey(zoneCode, date));
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final t = _ptFromJson(map);

      if (t.subuh.isEmpty || t.zohor.isEmpty || t.maghrib.isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedDay(
      String zoneCode,
      DateTime date,
      PrayerTimes times,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dayCacheKey(zoneCode, date),
      jsonEncode(_ptToJson(times)),
    );
  }

  // ===================== API HELPERS =====================

  Uri _buildUri({
    required String period,
    required String zoneCode,
    int? month,
    int? year,
  }) {
    final qp = <String, String>{
      'r': 'esolatApi/TakwimSolat',
      'period': period,
      'zone': zoneCode.toUpperCase(),
    };

    if (month != null) qp['month'] = month.toString().padLeft(2, '0');
    if (year != null) qp['year'] = year.toString();

    return Uri.parse('https://www.e-solat.gov.my/index.php').replace(
      queryParameters: qp,
    );
  }

  Map<String, dynamic> _decodeJsonMap(String body, {required String context}) {
    if (body.isEmpty) {
      throw Exception('$context: JAKIM memberi respons kosong.');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('$context: Format JSON JAKIM tidak sah.');
    }
    return decoded;
  }

  void _throwIfNoRecord(
      Map<String, dynamic> decoded, {
        required String zoneCode,
      }) {
    final status = decoded['status']?.toString();

    if (status == 'NO_RECORD!') {
      final isSabahZone = zoneCode.toUpperCase().startsWith('SBH');

      if (isSabahZone) {
        throw Exception(
          'Tiada rekod untuk Sabah (e-Solat/JAKIM).\n\n$sabahNoRecordMessage',
        );
      } else {
        throw Exception(
          'Tiada rekod ditemui untuk zon $zoneCode (e-Solat/JAKIM). Cuba zon lain atau cuba kemudian.',
        );
      }
    }
  }

  PrayerTimes _mapToPrayerTimes(
      Map<String, dynamic> row, {
        required String zoneCode,
      }) {
    final fajr = (row['fajr'] ?? row['Fajr'] ?? '').toString();
    final syuruk = (row['syuruk'] ?? row['Syuruk'] ?? '').toString();
    final dhuhr = (row['dhuhr'] ?? row['Dhuhr'] ?? '').toString();
    final asr = (row['asr'] ?? row['Asr'] ?? '').toString();
    final maghrib = (row['maghrib'] ?? row['Maghrib'] ?? '').toString();
    final isha =
    (row['isha'] ?? row['Isha'] ?? row['isyak'] ?? '').toString();
    // JAKIM provides hijri as e.g. "1447-12-03" — Malaysia's official
    // moon-sighting-based calendar. Safer than algorithmic conversion.
    final hijri = (row['hijri'] ?? row['Hijri'] ?? '').toString().trim();

    if (fajr.isEmpty ||
        syuruk.isEmpty ||
        dhuhr.isEmpty ||
        asr.isEmpty ||
        maghrib.isEmpty ||
        isha.isEmpty) {
      throw Exception('Data JAKIM tidak lengkap untuk zon $zoneCode.');
    }

    return PrayerTimes(
      subuh: fajr,
      syuruk: syuruk,
      zohor: dhuhr,
      asar: asr,
      maghrib: maghrib,
      isyak: isha,
      hijri: hijri,
    );
  }

  PrayerTimes _extractPrayerTimesFromDecoded(
      Map<String, dynamic> decoded, {
        required String zoneCode,
      }) {
    _throwIfNoRecord(decoded, zoneCode: zoneCode);

    final prayerTime = decoded['prayerTime'];

    if (prayerTime is List && prayerTime.isNotEmpty) {
      final first = prayerTime.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('Format rekod waktu solat tidak sah.');
      }
      return _mapToPrayerTimes(first, zoneCode: zoneCode);
    }

    if (prayerTime is Map<String, dynamic>) {
      final data = prayerTime['data'];
      if (data is List && data.isNotEmpty) {
        throw Exception(data.first.toString());
      }
    }

    throw Exception('Tiada data waktu solat untuk hari ini.');
  }

  DateTime? _parseJakimDate(String raw) {
    final s = raw.trim();

    final formats = <String>[
      'dd-MMM-yyyy',
      'dd-MMM-yy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
    ];

    for (final f in formats) {
      try {
        return _parseDateByFormat(s, f);
      } catch (_) {}
    }

    return null;
  }

  DateTime _parseDateByFormat(String value, String format) {
    if (format == 'dd/MM/yyyy') {
      final p = value.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    }

    if (format == 'yyyy-MM-dd') {
      final p = value.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    }

    if (format == 'dd-MM-yyyy') {
      final p = value.split('-');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    }

    if (format == 'dd-MMM-yyyy' || format == 'dd-MMM-yy') {
      final p = value.split('-');
      final day = int.parse(p[0]);
      final month = _monthFromShortName(p[1]);
      final year = int.parse(p[2].length == 2 ? '20${p[2]}' : p[2]);
      return DateTime(year, month, day);
    }

    throw FormatException('Unsupported format');
  }

  int _monthFromShortName(String m) {
    const map = <String, int>{
      'JAN': 1,
      'FEB': 2,
      'MAC': 3,
      'MAR': 3,
      'APR': 4,
      'MEI': 5,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'OGO': 8,
      'AUG': 8,
      'SEP': 9,
      'OKT': 10,
      'OCT': 10,
      'NOV': 11,
      'DIS': 12,
      'DEC': 12,
    };
    return map[m.trim().toUpperCase()] ?? 1;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  PrayerTimes? _extractPrayerTimesFromMonthlyDecoded(
      Map<String, dynamic> decoded, {
        required String zoneCode,
        required DateTime date,
      }) {
    _throwIfNoRecord(decoded, zoneCode: zoneCode);

    final list = decoded['prayerTime'];
    if (list is! List || list.isEmpty) return null;

    for (final row in list) {
      if (row is! Map<String, dynamic>) continue;

      final rawDate = (row['date'] ?? row['tarikh'] ?? '').toString().trim();
      if (rawDate.isEmpty) continue;

      final parsed = _parseJakimDate(rawDate);
      if (parsed == null) continue;

      if (_sameDate(parsed, date)) {
        return _mapToPrayerTimes(row, zoneCode: zoneCode);
      }
    }

    return null;
  }

  // Centralized helper so JAKIM's WAF accepts our requests.
  Future<http.Response> _getJson(Uri uri) {
    return JakimHttp.get(uri, client: _client, timeout: _timeout);
  }

  // ===================== SOURCE-SPECIFIC FETCHERS =====================

  Future<PrayerTimes> _fetchFromJakimToday(String zoneCode) async {
    final uri = _buildUri(period: 'today', zoneCode: zoneCode);
    final res = await _getJson(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('JAKIM today HTTP ${res.statusCode}');
    }

    final decoded = _decodeJsonMap(res.body, context: 'Waktu harian');
    return _extractPrayerTimesFromDecoded(decoded, zoneCode: zoneCode);
  }

  Future<PrayerTimes> _fetchFromJakimMonth(
      String zoneCode,
      DateTime date,
      ) async {
    final uri = _buildUri(
      period: 'month',
      zoneCode: zoneCode,
      month: date.month,
      year: date.year,
    );
    final res = await _getJson(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('JAKIM month HTTP ${res.statusCode}');
    }

    final decoded = _decodeJsonMap(res.body, context: 'Jadual bulanan');
    final times = _extractPrayerTimesFromMonthlyDecoded(
      decoded,
      zoneCode: zoneCode,
      date: date,
    );

    if (times == null) {
      throw Exception('JAKIM month: tiada rekod untuk tarikh ini.');
    }
    return times;
  }

  // ===================== PUBLIC API =====================

  /// Tries (in order):
  ///   1. Local cache
  ///   2. JAKIM e-Solat "today" endpoint
  ///   3. JAKIM e-Solat "month" endpoint
  ///   4. AlAdhan API (configured to JAKIM calculation method)
  ///
  /// Whichever succeeds first wins, and the result is cached.
  Future<PrayerTimes> fetchDay(
    String zoneCode,
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    // 1) cache first — UNLESS the caller explicitly asked for a fresh hit.
    // forceRefresh=true is used when the user taps the location pin and
    // expects the freshness timer to reset to 0. Skipping cache means the
    // JAKIM call below runs and _markFreshness writes "now" on success.
    if (!forceRefresh) {
      final cached = await readCachedDay(zoneCode, date);
      if (cached != null) {
        prefetchYearInBackground(zoneCode: zoneCode, year: date.year);
        await _bootstrapFreshnessIfMissing(zoneCode);
        return cached;
      }
    }

    Object? lastError;

    // 2) JAKIM today
    try {
      final times = await _fetchFromJakimToday(zoneCode);
      try {
        await _writeCachedDay(zoneCode, date, times);
        await _markFreshness(zoneCode, 'JAKIM');
      } catch (_) {}
      prefetchYearInBackground(zoneCode: zoneCode, year: date.year);
      return times;
    } catch (e) {
      lastError = e;
    }

    // 3) JAKIM month
    try {
      final times = await _fetchFromJakimMonth(zoneCode, date);
      try {
        await _writeCachedDay(zoneCode, date, times);
        await _markFreshness(zoneCode, 'JAKIM');
      } catch (_) {}
      prefetchYearInBackground(zoneCode: zoneCode, year: date.year);
      return times;
    } catch (e) {
      lastError = e;
    }

    // 4) AlAdhan fallback (silent — UI doesn't need to know)
    try {
      final times = await AlAdhanService.fetchDay(zone: zoneCode, date: date);
      try {
        await _writeCachedDay(zoneCode, date, times);
        await _markFreshness(zoneCode, 'AlAdhan');
      } catch (_) {}
      prefetchYearInBackground(zoneCode: zoneCode, year: date.year);
      return times;
    } catch (e) {
      lastError = e;
    }

    // All sources failed — surface the most recent error to the UI.
    throw Exception(
      lastError?.toString().replaceFirst('Exception: ', '') ??
          'Tiada sumber waktu solat tersedia.',
    );
  }

  Future<List<MonthlyPrayerEntry>> fetchMonth({
    required String zoneCode,
    required int month,
    required int year,
  }) async {
    final uri = _buildUri(
      period: 'month',
      zoneCode: zoneCode,
      month: month,
      year: year,
    );

    final res = await _getJson(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('JAKIM status ${res.statusCode}: ${res.reasonPhrase}');
    }

    final decoded = _decodeJsonMap(res.body, context: 'Jadual bulanan');
    _throwIfNoRecord(decoded, zoneCode: zoneCode);

    final list = decoded['prayerTime'];
    if (list is! List || list.isEmpty) return const <MonthlyPrayerEntry>[];

    final entries = <MonthlyPrayerEntry>[];
    for (final row in list) {
      if (row is! Map<String, dynamic>) continue;
      entries.add(MonthlyPrayerEntry.fromJakim(row));
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  // ===================== FRESHNESS TRACKING =====================

  Future<void> _markFreshness(String zoneCode, String source) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'lastSuccessfulFetch': DateTime.now().toIso8601String(),
      'source': source,
    });
    await prefs.setString(_freshnessKey(zoneCode), payload);
  }

  Future<void> _bootstrapFreshnessIfMissing(String zoneCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_freshnessKey(zoneCode)) == null) {
      await _markFreshness(zoneCode, 'JAKIM');
    }
  }

  Future<CacheHealth> getCacheHealth(String zoneCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_freshnessKey(zoneCode));
    if (raw == null) {
      return const CacheHealth(
        lastFetch: null, source: null, isFresh: false, isStale: true);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = DateTime.tryParse((map['lastSuccessfulFetch'] ?? '').toString());
      final src = (map['source'] ?? '').toString();
      if (ts == null) {
        return const CacheHealth(
          lastFetch: null, source: null, isFresh: false, isStale: true);
      }
      final age = DateTime.now().difference(ts);
      return CacheHealth(
        lastFetch: ts,
        source: src.isEmpty ? null : src,
        isFresh: age < const Duration(hours: 24),
        isStale: age > _staleThreshold,
      );
    } catch (_) {
      return const CacheHealth(
        lastFetch: null, source: null, isFresh: false, isStale: true);
    }
  }

  // ===================== YEAR PREFETCH =====================

  Future<int> prefetchYear({
    required String zoneCode,
    required int year,
    bool force = false,
    void Function(int monthsDone)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final metaKey = _yearMetaKey(zoneCode, year);

    if (!force) {
      final existing = prefs.getString(metaKey);
      if (existing != null) {
        try {
          final m = jsonDecode(existing) as Map<String, dynamic>;
          final at = DateTime.tryParse((m['fetchedAt'] ?? '').toString());
          if (at != null &&
              DateTime.now().difference(at) < _yearRefreshCooldown) {
            return (m['entryCount'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }
    }

    int totalWritten = 0;
    for (int month = 1; month <= 12; month++) {
      try {
        final entries = await fetchMonth(
          zoneCode: zoneCode,
          month: month,
          year: year,
        );
        for (final e in entries) {
          await _writeCachedDay(
            zoneCode,
            e.date,
            PrayerTimes(
              subuh: e.subuh,
              syuruk: e.syuruk,
              zohor: e.zohor,
              asar: e.asar,
              maghrib: e.maghrib,
              isyak: e.isyak,
              hijri: e.hijri,
            ),
          );
          totalWritten++;
        }
        onProgress?.call(month);
      } catch (_) {}
      if (month < 12) await Future.delayed(_interMonthDelay);
    }

    if (totalWritten > 0) {
      await prefs.setString(metaKey, jsonEncode({
        'fetchedAt': DateTime.now().toIso8601String(),
        'entryCount': totalWritten,
      }));
      await _markFreshness(zoneCode, 'JAKIM');
    }

    return totalWritten;
  }

  void prefetchYearInBackground({
    required String zoneCode,
    required int year,
  }) {
    // ignore: unawaited_futures
    Future(() async {
      try {
        await prefetchYear(zoneCode: zoneCode, year: year);
      } catch (_) {}
    });
  }

  // ===================== CACHE HYGIENE =====================

  Future<int> purgeOldCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final cutoff = DateTime.now().subtract(_cacheRetention);
    int purged = 0;

    for (final k in keys) {
      if (!k.startsWith('$_cachePrefixDay:')) continue;
      final parts = k.split(':');
      if (parts.length < 3) continue;
      final ymd = parts.last;
      if (ymd.length != 8) continue;

      final y = int.tryParse(ymd.substring(0, 4));
      final m = int.tryParse(ymd.substring(4, 6));
      final d = int.tryParse(ymd.substring(6, 8));
      if (y == null || m == null || d == null) continue;

      try {
        final entryDate = DateTime(y, m, d);
        if (entryDate.isBefore(cutoff)) {
          await prefs.remove(k);
          purged++;
        }
      } catch (_) {}
    }
    return purged;
  }

  void dispose() {
    _client.close();
  }
}

class CacheHealth {
  final DateTime? lastFetch;
  final String? source;
  final bool isFresh;
  final bool isStale;

  const CacheHealth({
    required this.lastFetch,
    required this.source,
    required this.isFresh,
    required this.isStale,
  });

  String toBahasaLabel() {
    if (lastFetch == null) return 'Memuat data buat kali pertama…';
    final age = DateTime.now().difference(lastFetch!);
    final src = source ?? 'JAKIM';

    String ago;
    if (age.inMinutes < 1) {
      ago = 'sebentar tadi';
    } else if (age.inMinutes < 60) {
      ago = '${age.inMinutes} minit lalu';
    } else if (age.inHours < 24) {
      ago = '${age.inHours} jam lalu';
    } else if (age.inDays == 1) {
      ago = 'semalam';
    } else if (age.inDays < 7) {
      ago = '${age.inDays} hari lalu';
    } else {
      ago = '${age.inDays} hari lalu (perlu dikemaskini)';
    }
    return 'Sumber: $src • Dikemas kini $ago';
  }
}