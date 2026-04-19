// lib/services/jakim_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_times.dart';

class JakimService {
  static const _host = 'www.e-solat.gov.my';
  static const _headers = {'accept': 'application/json'};

  /// iOS-compatible “today” fetch (same endpoint your Swift code uses).
  static Future<PrayerTimes> fetchToday({required String zone}) async {
    final uri = Uri.https(_host, '/index.php', {
      'r': 'esolatApi/TakwimSolat',
      'period': 'today',
      'zone': zone.toUpperCase(),
    });

    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final root = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (root['prayerTime'] ?? root['data'] ?? []) as List<dynamic>;
    if (list.isEmpty) throw Exception('Tiada data waktu solat untuk hari ini.');
    final m = (list.first as Map<String, dynamic>);

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    /// Format "HH:mm" to "h:mm AM/PM".
    /// If [forcePm] is true, we *guarantee* the result ends in PM.
    String to12h(String raw, {bool forcePm = false}) {
      if (raw.isEmpty) return raw;

      // Accept "HH:mm" or "HH:mm:ss"
      final parts = raw.split(':');
      int h = int.tryParse(parts[0]) ?? 0;
      int min = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

      // If this is an afternoon/evening prayer and the hour is 01..11, convert to 13..23 (PM).
      if (forcePm && h < 12) h += 12;

      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, h, min);
      final hh = (dt.hour % 12 == 0) ? 12 : (dt.hour % 12);
      final mm = dt.minute.toString().padLeft(2, '0');
      var ap = dt.hour >= 12 ? 'PM' : 'AM';

      // FINAL GUARD: if this slot must be PM but formatting says AM, flip it.
      if (forcePm && ap == 'AM') ap = 'PM';

      return '$hh:$mm $ap';
    }

    final subuh   = to12h(pick(['fajr', 'Fajr']));
    final syuruk  = to12h(pick(['syuruk', 'Syuruk', 'sunrise', 'Sunrise']));
    final zohor   = to12h(pick(['dhuhr', 'Dhuhr', 'zohor', 'Zohor', 'zuhr', 'Zuhr']), forcePm: true);
    final asar    = to12h(pick(['asr', 'Asr']), forcePm: true);
    final maghrib = to12h(pick(['maghrib', 'Maghrib']), forcePm: true);
    final isyak   = to12h(pick(['isha', 'Isha', 'isyak', 'Isyak']), forcePm: true);

    return PrayerTimes(
      subuh: subuh,
      syuruk: syuruk,
      zohor: zohor,
      asar: asar,
      maghrib: maghrib,
      isyak: isyak,
    );
  }

  /// Backward-compatible alias (some code may still call this).
  static Future<PrayerTimes> fetchDay({
    required String zone,
    required DateTime date,
  }) {
    // e-Solat "today" is what your Swift app uses; this keeps parity.
    return fetchToday(zone: zone);
  }
}