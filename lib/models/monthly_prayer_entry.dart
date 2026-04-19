// lib/models/monthly_prayer_entry.dart

/// One row in the monthly timetable (for a single day).
class MonthlyPrayerEntry {
  final DateTime date;
  final String subuh;
  final String syuruk;
  final String zohor;
  final String asar;
  final String maghrib;
  final String isyak;

  const MonthlyPrayerEntry({
    required this.date,
    required this.subuh,
    required this.syuruk,
    required this.zohor,
    required this.asar,
    required this.maghrib,
    required this.isyak,
  });

  /// Build from a single JAKIM JSON object.
  factory MonthlyPrayerEntry.fromJakim(Map<String, dynamic> json) {
    // JAKIM usually uses "date" like "2025-11-01".
    final rawDate = (json['date'] ?? json['tarikh'] ?? '') as String;

    DateTime parsedDate;
    if (rawDate.isEmpty) {
      parsedDate = DateTime.now();
    } else {
      parsedDate = _parseDateFlexible(rawDate);
    }

    String pick(String a, String b) =>
        (json[a] ?? json[b] ?? '') as String;

    return MonthlyPrayerEntry(
      date: parsedDate,
      subuh: pick('fajr', 'Fajr'),
      syuruk: pick('syuruk', 'Syuruk'),
      zohor: pick('dhuhr', 'Dhuhr'),
      asar: pick('asr', 'Asr'),
      maghrib: pick('maghrib', 'Maghrib'),
      isyak: pick('isha', 'Isha'),
    );
  }

  static DateTime _parseDateFlexible(String s) {
    // Normalise separators
    final cleaned = s.trim().split(' ').first.replaceAll('/', '-');
    try {
      return DateTime.parse(cleaned);
    } catch (_) {
      // Fallback: try dd-MM-yyyy
      final parts = cleaned.split('-');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]) ?? 1;
        final m = int.tryParse(parts[1]) ?? 1;
        final y = int.tryParse(parts[2]) ?? DateTime.now().year;
        return DateTime(y, m, d);
      }
      return DateTime.now();
    }
  }
}