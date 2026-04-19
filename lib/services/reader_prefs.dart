import 'package:mysolat/services/prefs_service.dart';
// lib/services/reader_prefs.dart
import 'dart:convert';

class LastRead {
  final int surah;
  final int ayah;
  const LastRead(this.surah, this.ayah);
}

class Bookmark {
  final int surah;       // 1..114
  final int ayah;        // 1-based
  final DateTime at;     // when set

  const Bookmark({required this.surah, required this.ayah, required this.at});

  Map<String, dynamic> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'at': at.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    surah: j['surah'] ?? 0,
    ayah: j['ayah'] ?? 0,
    at: DateTime.tryParse(j['at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class ReaderPrefs {
  static const _kShowMalay = 'reader_show_malay';
  static const _kArabicSize = 'reader_arabic_size';
  static const _kMalaySize = 'reader_malay_size';

  // NEW multi-bookmark storage (max 2, MRU)
  static const _kBookmarks = 'reader_bookmarks_v2';

  // ---------------- Font & translation prefs ----------------
  static Future<bool> setShowMalay(bool v) async {
    final p = PrefsService.instance;
    return p.setBool(_kShowMalay, v);
  }

  static Future<bool> getShowMalay() async {
    final p = PrefsService.instance;
    return p.getBool(_kShowMalay) ?? true;
  }

  static Future<bool> setArabicSize(double v) async {
    final p = PrefsService.instance;
    return p.setDouble(_kArabicSize, v);
  }

  static Future<double> getArabicSize() async {
    final p = PrefsService.instance;
    return p.getDouble(_kArabicSize) ?? 28;
  }

  static Future<bool> setMalaySize(double v) async {
    final p = PrefsService.instance;
    return p.setDouble(_kMalaySize, v);
  }

  static Future<double> getMalaySize() async {
    final p = PrefsService.instance;
    return p.getDouble(_kMalaySize) ?? 16;
  }

  // ---------------- Bookmarks (max 2, MRU) ----------------
  static Future<List<Bookmark>> getBookmarks() async {
    final p = PrefsService.instance;
    final raw = p.getStringList(_kBookmarks) ?? const <String>[];
    final list = <Bookmark>[];
    for (final s in raw) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        list.add(Bookmark.fromJson(j));
      } catch (_) {}
    }
    // sort newest first, safety
    list.sort((a, b) => b.at.compareTo(a.at));
    return list.take(2).toList(growable: false);
  }

  static Future<void> _saveBookmarks(List<Bookmark> items) async {
    final p = PrefsService.instance;
    // newest first, max 2
    items.sort((a, b) => b.at.compareTo(a.at));
    final trimmed = items.take(2).toList(growable: false);
    final raw = trimmed.map((b) => jsonEncode(b.toJson())).toList(growable: false);
    await p.setStringList(_kBookmarks, raw);
  }

  /// Add/refresh a bookmark (surah, ayah). Keeps at most 2, newest first.
  static Future<void> addBookmark(int surah, int ayah) async {
    final now = DateTime.now();
    final existing = await getBookmarks();
    // If same surah+ayah exists, update timestamp; if same surah with different ayah, replace it.
    final filtered = existing
        .where((b) => !(b.surah == surah && b.ayah == ayah))
        .where((b) => !(b.surah == surah && b.ayah != ayah))
        .toList();
    filtered.insert(0, Bookmark(surah: surah, ayah: ayah, at: now));
    await _saveBookmarks(filtered);
  }

  /// Most recent bookmark (or null).
  static Future<Bookmark?> latestBookmark() async {
    final all = await getBookmarks();
    return all.isEmpty ? null : all.first;
  }

  /// Bookmark for a specific surah, if any.
  static Future<Bookmark?> getBookmarkForSurah(int surah) async {
    final all = await getBookmarks();
    try {
      return all.firstWhere((b) => b.surah == surah);
    } catch (_) {
      return null;
    }
  }

  /// Last-read convenience for a surah: returns ayah if bookmarked.
  static Future<int?> getLastReadForSurah(int surah) async {
    final b = await getBookmarkForSurah(surah);
    return b?.ayah;
  }
}