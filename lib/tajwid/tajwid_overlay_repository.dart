// lib/tajwid/tajwid_overlay_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'tajwid_overlay_models.dart';

class TajwidOverlayRepository {
  TajwidOverlayRepository._();
  static final TajwidOverlayRepository instance = TajwidOverlayRepository._();

  Map<String, List<TajwidRange>>? _cache;

  Future<Map<String, List<TajwidRange>>> load({
    String path = 'assets/tajwid/tajwid_ranges.json',
  }) async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(path);
    final Map<String, dynamic> jsonMap = jsonDecode(raw);

    final out = <String, List<TajwidRange>>{};
    for (final entry in jsonMap.entries) {
      final verseKey = entry.key;
      final list = (entry.value as List)
          .map((e) => TajwidRange.fromJson((e as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.s.compareTo(b.s));
      out[verseKey] = list;
    }

    _cache = out;
    return out;
  }
}