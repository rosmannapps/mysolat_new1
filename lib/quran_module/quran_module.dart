import 'package:flutter/material.dart';

// Import your al_quran types from its module file.
// NOTE: We only import the TYPES and the SurahReaderPage widget.
import 'al_quran_app/main.dart'
    show QuranSurah, QuranArabicOnlyBundle, LocalTranslationStore, BookmarkStore, ReaderSettingsStore, SurahReaderPage;

/// One global holder for the al_quran resources.
///
/// IMPORTANT:
/// Your project currently has analyzer errors because these classes DO NOT have
/// default (unnamed) constructors in your `al_quran_app/main.dart`:
/// - QuranArabicOnlyBundle(...) requires arguments (e.g. `surahs:`)
/// - LocalTranslationStore(...) has no unnamed constructor
///
/// Therefore, we do NOT instantiate them here.
/// Instead, create them where you already do (inside your Quran module / app init)
/// and then call [QuranModule.I.configure(...)] once.
class QuranModule {
  QuranModule._();

  static final QuranModule I = QuranModule._();

  bool _ready = false;

  QuranArabicOnlyBundle? quran;
  LocalTranslationStore? translations;
  BookmarkStore? bookmarks;
  ReaderSettingsStore? settingsStore;

  // Fonts used by al_quran UI
  String quranFontFamily = 'KFGQPC';
  String arabicTitleFamily = 'KFGQPC';

  /// Inject the instances from your Quran module.
  ///
  /// Call this once during app startup (or before opening Quran pages).
  void configure({
    required QuranArabicOnlyBundle quran,
    required LocalTranslationStore translations,
    required BookmarkStore bookmarks,
    required ReaderSettingsStore settingsStore,
    String? quranFontFamily,
    String? arabicTitleFamily,
  }) {
    this.quran = quran;
    this.translations = translations;
    this.bookmarks = bookmarks;
    this.settingsStore = settingsStore;

    if (quranFontFamily != null) this.quranFontFamily = quranFontFamily;
    if (arabicTitleFamily != null) this.arabicTitleFamily = arabicTitleFamily;

    _ready = true;
  }

  /// Ensures the module is configured.
  ///
  /// This is async to keep the same API you already used, but the work is
  /// currently synchronous (just validation).
  Future<void> ensureReady() async {
    if (_ready) return;

    // Make failures obvious and readable.
    throw StateError(
      'QuranModule is not configured.\n\n'
      'Fix: create QuranArabicOnlyBundle / LocalTranslationStore / BookmarkStore / ReaderSettingsStore '
      'using your al_quran_app loaders, then call:\n\n'
      'QuranModule.I.configure(quran: ..., translations: ..., bookmarks: ..., settingsStore: ...);',
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

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(
          surah: surah,
          quran: q,
          translations: t,
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