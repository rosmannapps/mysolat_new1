// lib/services/aladhan_service.dart
//
// Fallback prayer times provider, used when JAKIM e-Solat API is unreachable.
//
// AlAdhan (https://aladhan.com/prayer-times-api) is a free public API with
// no API key required. We use its calculation method 17 ("Jabatan Kemajuan
// Islam Malaysia (JAKIM)") so the returned times match JAKIM as closely
// as possible — typically within 1 minute.
//
// We submit coordinates (not city names) so each JAKIM zone gets times
// for its representative town, matching what users expect.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_times.dart';

class AlAdhanService {
  AlAdhanService._();

  static const String _host = 'api.aladhan.com';

  /// AlAdhan calculation method ID. 17 = JAKIM (Malaysia).
  static const int _calcMethod = 17;

  /// School: 0 = Shafi (default for Malaysia), 1 = Hanafi.
  static const int _school = 0;

  static const Duration _timeout = Duration(seconds: 20);

  /// Fetch today's (or [date]'s) prayer times for a JAKIM zone code.
  /// Returns the same [PrayerTimes] shape as the JAKIM service so callers
  /// don't need to know which source the data came from.
  static Future<PrayerTimes> fetchDay({
    required String zone,
    required DateTime date,
  }) async {
    final coords = _zoneCoords[zone.toUpperCase()];
    if (coords == null) {
      throw Exception(
        'AlAdhan: zon $zone tidak dipetakan ke koordinat.',
      );
    }

    final dateStr =
        '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';

    final uri = Uri.https(_host, '/v1/timings/$dateStr', {
      'latitude': coords.$1.toString(),
      'longitude': coords.$2.toString(),
      'method': _calcMethod.toString(),
      'school': _school.toString(),
    });

    final resp = await http.get(uri).timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('AlAdhan HTTP ${resp.statusCode}');
    }

    final root = jsonDecode(resp.body);
    if (root is! Map<String, dynamic>) {
      throw Exception('AlAdhan: respons tidak sah.');
    }

    final data = root['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('AlAdhan: data hilang dalam respons.');
    }

    final timings = data['timings'];
    if (timings is! Map<String, dynamic>) {
      throw Exception('AlAdhan: medan timings hilang.');
    }

    String clean(String key) {
      final raw = timings[key]?.toString() ?? '';
      // AlAdhan sometimes appends timezone like "05:42 (+08)" — strip it.
      final hhmm = raw.split(' ').first.trim();
      // Pad to HH:mm:ss to match JAKIM's format (callers expect that).
      if (hhmm.split(':').length == 2) return '$hhmm:00';
      return hhmm;
    }

    final fajr = clean('Fajr');
    final syuruk = clean('Sunrise');
    final dhuhr = clean('Dhuhr');
    final asr = clean('Asr');
    final maghrib = clean('Maghrib');
    final isha = clean('Isha');

    if (fajr.isEmpty ||
        syuruk.isEmpty ||
        dhuhr.isEmpty ||
        asr.isEmpty ||
        maghrib.isEmpty ||
        isha.isEmpty) {
      throw Exception('AlAdhan: data waktu solat tidak lengkap.');
    }

    return PrayerTimes(
      subuh: fajr,
      syuruk: syuruk,
      zohor: dhuhr,
      asar: asr,
      maghrib: maghrib,
      isyak: isha,
    );
  }

  // ===================================================================
  // JAKIM zone code → (latitude, longitude) of the zone's main town.
  //
  // Coordinates are approximate (representative town in each zone).
  // For very large or remote zones (e.g., Royal Belum, Mt Kinabalu),
  // the geographic centre is used.
  // ===================================================================
  static const Map<String, (double, double)> _zoneCoords = {
    // Johor
    'JHR01': (2.4500, 104.5000),  // Pulau Aur, Pulau Pemanggil
    'JHR02': (1.4854, 103.7611),  // Johor Bahru
    'JHR03': (2.0303, 103.3186),  // Kluang
    'JHR04': (1.8548, 102.9325),  // Batu Pahat

    // Kedah
    'KDH01': (6.1184, 100.3685),  // Alor Setar
    'KDH02': (5.6497, 100.4945),  // Sungai Petani
    'KDH03': (5.6500, 100.7500),  // Sik
    'KDH04': (5.6750, 100.9192),  // Baling
    'KDH05': (5.3608, 100.5664),  // Kulim
    'KDH06': (6.3500, 99.8000),   // Langkawi
    'KDH07': (5.7869, 100.4364),  // Gunung Jerai

    // Kelantan
    'KTN01': (6.1254, 102.2381),  // Kota Bharu
    'KTN02': (5.7322, 101.7382),  // Jeli

    // Melaka
    'MLK01': (2.1896, 102.2501),  // Bandar Melaka

    // Negeri Sembilan
    'NGS01': (2.4682, 102.2333),  // Tampin
    'NGS02': (2.7374, 102.2553),  // Kuala Pilah
    'NGS03': (2.7297, 101.9381),  // Seremban

    // Pahang
    'PHG01': (2.7903, 104.1632),  // Pulau Tioman
    'PHG02': (3.8077, 103.3260),  // Kuantan
    'PHG03': (3.4500, 102.4167),  // Temerloh
    'PHG04': (3.5247, 101.9077),  // Bentong
    'PHG05': (3.4078, 101.7917),  // Genting Sempah
    'PHG06': (4.4719, 101.3786),  // Cameron Highlands

    // Perlis
    'PLS01': (6.4414, 100.1986),  // Kangar

    // Pulau Pinang
    'PNG01': (5.4141, 100.3288),  // Georgetown

    // Perak
    'PRK01': (4.1991, 101.2603),  // Tapah
    'PRK02': (4.5975, 101.0901),  // Ipoh
    'PRK03': (5.4275, 100.9772),  // Grik
    'PRK04': (5.5500, 101.5500),  // Royal Belum / Temengor
    'PRK05': (4.0263, 101.0203),  // Teluk Intan
    'PRK06': (4.8508, 100.7390),  // Taiping
    'PRK07': (4.8642, 100.7950),  // Bukit Larut

    // Sabah
    'SBH01': (5.8439, 118.1170),  // Sandakan
    'SBH02': (5.7333, 117.6667),  // Beluran
    'SBH03': (5.0290, 118.3270),  // Lahad Datu
    'SBH04': (4.2438, 117.8911),  // Tawau
    'SBH05': (6.8830, 116.8454),  // Kudat
    'SBH06': (6.0750, 116.5583),  // Gunung Kinabalu
    'SBH07': (5.9788, 116.0753),  // Kota Kinabalu
    'SBH08': (5.3373, 116.1604),  // Keningau
    'SBH09': (5.3450, 115.7460),  // Beaufort

    // Sarawak
    'SWK01': (4.7506, 115.0058),  // Limbang
    'SWK02': (4.3995, 113.9914),  // Miri
    'SWK03': (3.1670, 113.0414),  // Bintulu
    'SWK04': (2.2870, 111.8307),  // Sibu
    'SWK05': (2.1265, 111.5170),  // Sarikei
    'SWK06': (1.2376, 111.4632),  // Sri Aman
    'SWK07': (1.1631, 110.5642),  // Serian
    'SWK08': (1.5535, 110.3593),  // Kuching
    'SWK09': (1.5500, 110.4000),  // Kampung Patarikan

    // Selangor
    'SGR01': (3.0738, 101.5183),  // Shah Alam
    'SGR02': (3.3398, 101.2531),  // Kuala Selangor
    'SGR03': (3.0438, 101.4456),  // Klang

    // Terengganu
    'TRG01': (5.3296, 103.1370),  // Kuala Terengganu
    'TRG02': (5.7829, 102.5556),  // Besut
    'TRG03': (5.0730, 102.7170),  // Kuala Berang
    'TRG04': (4.7700, 103.4167),  // Dungun

    // Wilayah Persekutuan
    'WLY01': (3.1390, 101.6869),  // Kuala Lumpur
    'WLY02': (5.2767, 115.2417),  // Labuan
  };
}