// lib/models/prayer_times.dart
import 'dart:convert';

/// Simple model representing one day's prayer times from JAKIM.
class PrayerTimes {
  final String subuh;
  final String syuruk;
  final String zohor;
  final String asar;
  final String maghrib;
  final String isyak;

  const PrayerTimes({
    required this.subuh,
    required this.syuruk,
    required this.zohor,
    required this.asar,
    required this.maghrib,
    required this.isyak,
  });

  /// Safe empty fallback (for cache miss / decode fail).
  static const PrayerTimes empty = PrayerTimes(
    subuh: '',
    syuruk: '',
    zohor: '',
    asar: '',
    maghrib: '',
    isyak: '',
  );

  /// Create from a JSON map.
  /// Supports both your naming and other common API keys just in case.
  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    return PrayerTimes(
      subuh: pick(['subuh', 'fajr']),
      syuruk: pick(['syuruk', 'sunrise', 'syuruq']),
      zohor: pick(['zohor', 'dhuhr', 'zuhr']),
      asar: pick(['asar', 'asr']),
      maghrib: pick(['maghrib']),
      isyak: pick(['isyak', 'isha']),
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'subuh': subuh,
    'syuruk': syuruk,
    'zohor': zohor,
    'asar': asar,
    'maghrib': maghrib,
    'isyak': isyak,
  };

  /// Encode to a String (ideal for SharedPreferences).
  String encode() => jsonEncode(toJson());

  /// Decode from a String (SharedPreferences).
  static PrayerTimes decode(String s) {
    try {
      final obj = jsonDecode(s);
      if (obj is Map<String, dynamic>) return PrayerTimes.fromJson(obj);
      if (obj is Map) return PrayerTimes.fromJson(obj.cast<String, dynamic>());
    } catch (_) {}
    return PrayerTimes.empty;
  }
}