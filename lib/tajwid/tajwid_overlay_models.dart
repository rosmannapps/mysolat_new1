// lib/tajwid/tajwid_overlay_models.dart
class TajwidRange {
  final int s; // start rune index (inclusive)
  final int e; // end rune index (exclusive)
  final String r; // rule key

  const TajwidRange({required this.s, required this.e, required this.r});

  factory TajwidRange.fromJson(Map<String, dynamic> j) {
    return TajwidRange(
      s: (j['s'] as num).toInt(),
      e: (j['e'] as num).toInt(),
      r: (j['r'] as String).trim(),
    );
  }
}