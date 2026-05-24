import 'package:flutter/material.dart';

import 'al_quran_app/main.dart'
    show
        QuranSurah,
        QuranArabicOnlyBundle,
        LocalTranslationStore,
        BookmarkStore,
        ReaderSettingsStore,
        SurahReaderPage,
        TajweedStore;

class QuranModule {
  QuranModule._();

  static final QuranModule I = QuranModule._();

  bool _ready = false;

  QuranArabicOnlyBundle? quran;
  LocalTranslationStore? translations;
  BookmarkStore? bookmarks;
  ReaderSettingsStore? settingsStore;
  TajweedStore? tajweed;

  String quranFontFamily = 'KFGQPC';
  String arabicTitleFamily = 'KFGQPC';

  void configure({
    required QuranArabicOnlyBundle quran,
    required LocalTranslationStore translations,
    required BookmarkStore bookmarks,
    required ReaderSettingsStore settingsStore,
    required TajweedStore tajweed,
    String? quranFontFamily,
    String? arabicTitleFamily,
  }) {
    this.quran = quran;
    this.translations = translations;
    this.bookmarks = bookmarks;
    this.settingsStore = settingsStore;
    this.tajweed = tajweed;

    if (quranFontFamily != null) {
      this.quranFontFamily = quranFontFamily;
    }

    if (arabicTitleFamily != null) {
      this.arabicTitleFamily = arabicTitleFamily;
    }

    _ready = true;
  }

  Future<void> ensureReady() async {
    if (_ready) return;

    throw StateError(
      'QuranModule is not configured.\n\n'
      'Fix: create QuranArabicOnlyBundle / LocalTranslationStore / '
      'BookmarkStore / ReaderSettingsStore / TajweedStore, then call:\n\n'
      'QuranModule.I.configure(quran: ..., translations: ..., bookmarks: ..., '
      'settingsStore: ..., tajweed: ...);',
    );
  }

  Future<void> openSurah(
    BuildContext context, {
    required QuranSurah surah,
    int startAyah = 1,
  }) async {
    await ensureReady();

    final q = quran!;
    final t = translations!;
    final b = bookmarks!;
    final s = settingsStore!;
    final tw = tajweed!;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(
          surah: surah,
          quran: q,
          translations: t,
          tajweed: tw,
          bookmarks: b,
          settingsStore: s,
          quranFontFamily: quranFontFamily,
          arabicTitleFamily: arabicTitleFamily,
          startAyah: startAyah,
        ),
      ),
    );
  }
}
