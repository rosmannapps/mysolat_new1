// lib/services/bookmark_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final int surahNumber;
  final String surahLatin;
  final String surahArabic;
  final int ayahNumber;

  Bookmark({
    required this.surahNumber,
    required this.surahLatin,
    required this.surahArabic,
    required this.ayahNumber,
  });

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'surahLatin': surahLatin,
    'surahArabic': surahArabic,
    'ayahNumber': ayahNumber,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    surahNumber: json['surahNumber'] as int,
    surahLatin: json['surahLatin'] as String,
    surahArabic: json['surahArabic'] as String,
    ayahNumber: json['ayahNumber'] as int,
  );
}

class BookmarkStorage {
  static const _key = 'quran_bookmarks_v1';

  static Future<List<Bookmark>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final List list = jsonDecode(raw) as List;
    return list
        .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveBookmarks(List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
    jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Add or update a bookmark (one per surah+ayah). Newest at the top.
  static Future<void> addOrUpdate(Bookmark bookmark) async {
    final list = await loadBookmarks();
    final idx = list.indexWhere((b) =>
    b.surahNumber == bookmark.surahNumber &&
        b.ayahNumber == bookmark.ayahNumber);
    if (idx >= 0) {
      list[idx] = bookmark;
    } else {
      list.insert(0, bookmark);
    }
    await _saveBookmarks(list);
  }

  static Future<void> remove(Bookmark bookmark) async {
    final list = await loadBookmarks();
    list.removeWhere((b) =>
    b.surahNumber == bookmark.surahNumber &&
        b.ayahNumber == bookmark.ayahNumber);
    await _saveBookmarks(list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}