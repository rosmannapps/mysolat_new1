import '../../../services/prefs_service.dart';
import '../../../services/quran_audio_service.dart';
// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback, Clipboard, ClipboardData;
import 'package:xml/xml.dart';

import 'tajwid/tajwid_rich_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  runApp(const MyApp());
}

const Color kSeed = AppTheme.primary;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color kSeed = AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Qur'an",
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // keep background dark (nice)
        scaffoldBackgroundColor: const Color(0xFF0E0F12),

        // ✅ make primary a LIGHT GREEN in dark mode
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSeed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8FE6B5), // light green (more visible)
          secondary: const Color(0xFF8FE6B5),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const QuranHomePage(),
    );
  }
}

// =====================================================
// Home (Tabs: Surah / Juz / Bookmark)
// =====================================================

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  static const String kUthmaniXmlPath = 'assets/quran/quran-uthmani.xml';
  static const String kFontQuran = 'KFGQPC';
  static const String kFontArabicTitle = 'AmiriQuran';

  late Future<_AppBundle> _future;

  final _bookmarks = BookmarkStore();
  final _settings = ReaderSettingsStore();

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<_AppBundle> _loadAll() async {
    await _bookmarks.load();
    await _settings.load();

    final q = await QuranLoader.loadArabicOnly(
      uthmaniXmlPath: kUthmaniXmlPath,
    );

    final t = await LocalTranslationStore.loadWithQuran(
      quran: q,
      msPath: 'assets/translations/ms.json',
      enPath: 'assets/translations/en.json',
    );

    final tajweed = await TajweedStore.load(
      path: 'assets/tajwid/quran_tajweed.json',
    );

    debugPrint('✅ MS count: ${t.debugCountMs}, EN count: ${t.debugCountEn}');
    debugPrint('✅ Tajweed loaded');

    return _AppBundle(
      quran: q,
      translations: t,
      tajweed: tajweed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = cs.primary;
    final onSurface = cs.onSurface;
    final surface = cs.surface;

    return FutureBuilder<_AppBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Qur'an")),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Load error:\n${snap.error}'),
            ),
          );
        }

        final bundle = snap.data!;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              title: Text(
                "Qur'an",
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white),
              ),
              actions: [
                IconButton(
                  tooltip: 'Cari / Lompat',
                  icon: const Icon(Icons.search),
                  onPressed: () => _openSearch(context, bundle.quran),
                ),
                IconButton(
                  tooltip: 'Tetapan Bacaan',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openReaderSettings(context, isDark),
                ),
              ],
              bottom: TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'SURAH'),
                  Tab(text: 'JUZ'),
                  Tab(text: 'BOOKMARK'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                SurahTab(
                  quran: bundle.quran,
                  primary: primary,
                  arabicTitleFamily: kFontArabicTitle,
                  bookmarks: _bookmarks,
                  onOpenSurah: (s) =>
                      _openSurahReader(context, bundle, s, startAyah: 1),
                ),
                JuzTab(
                  quran: bundle.quran,
                  primary: primary,
                  onOpen: (surahNo, ayahNo) {
                    final surah = bundle.quran.surahs
                        .firstWhere((x) => x.number == surahNo);
                    _openSurahReader(context, bundle, surah, startAyah: ayahNo);
                  },
                ),
                BookmarkTab(
                  quran: bundle.quran,
                  store: _bookmarks,
                  primary: primary,
                  onOpen: (surahNo, ayahNo) {
                    final surah = bundle.quran.surahs
                        .firstWhere((x) => x.number == surahNo);
                    _openSurahReader(context, bundle, surah, startAyah: ayahNo);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSearch(
      BuildContext context, QuranArabicOnlyBundle quran) async {
    final result = await showModalBottomSheet<_JumpResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(quran: quran),
    );
    if (!mounted || result == null) return;

    final surah =
        quran.surahs.firstWhere((s) => s.number == result.surahNumber);
    final bundle = await _future;
    if (!mounted) return;

    _openSurahReader(context, bundle, surah, startAyah: result.ayahNumber);
  }

  // ✅ Realtime settings: no return value, no Simpan needed
  Future<void> _openReaderSettings(BuildContext context, bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReaderSettingsSheet(isDark: isDark, store: _settings),
    );
  }

  void _openSurahReader(
    BuildContext context,
    _AppBundle bundle,
    QuranSurah surah, {
    required int startAyah,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(
          tajweed: bundle.tajweed,
          surah: surah,
          quran: bundle.quran,
          translations: bundle.translations,
          bookmarks: _bookmarks,
          settingsStore: _settings,
          quranFontFamily: kFontQuran,
          arabicTitleFamily: kFontArabicTitle,
          startAyah: startAyah,
        ),
      ),
    );
  }
}

// =====================================================
// Surah Tab
// =====================================================

class SurahTab extends StatelessWidget {
  final QuranArabicOnlyBundle quran;
  final Color primary;
  final String arabicTitleFamily;
  final ValueChanged<QuranSurah> onOpenSurah;
  final BookmarkStore? bookmarks;
  const SurahTab({
    super.key,
    required this.quran,
    required this.primary,
    required this.arabicTitleFamily,
    required this.onOpenSurah,
    this.bookmarks,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: quran.surahs.length,
      itemBuilder: (context, i) {
        final s = quran.surahs[i];
        final hasBookmark =
            bookmarks?.items.any((bm) => bm.surahNumber == s.number) ?? false;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpenSurah(s),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      OctaBadge(
                          number: s.number,
                          size: 44,
                          stroke: primary.withOpacity(0.65)),
                      if (hasBookmark)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.displayNameEn,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white.withOpacity(0.90)
                                : Colors.black.withOpacity(0.88),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s.revelationLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${s.ayahCount} ayat',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withOpacity(0.50)
                                    : Colors.black.withOpacity(0.40),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.nameAr,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: arabicTitleFamily,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white.withOpacity(0.75)
                          : Colors.black.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =====================================================
// Juz Tab
// =====================================================

class JuzTab extends StatelessWidget {
  final QuranArabicOnlyBundle quran;
  final Color primary;
  final void Function(int surahNo, int ayahNo) onOpen;

  const JuzTab({
    super.key,
    required this.quran,
    required this.primary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = JuzIndex.rows;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      itemCount: rows.length,
      separatorBuilder: (_, __) => Divider(
          height: 1,
          color:
              Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 1.0)),
      itemBuilder: (context, i) {
        final r = rows[i];
        final title = 'Juz ${r.juz}';
        final sub = 'Start: ${r.surah}:${r.ayah}';

        return InkWell(
          onTap: () => onOpen(r.surah, r.ayah),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                OctaBadge(
                    number: r.juz, size: 44, stroke: primary.withOpacity(0.65)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white.withOpacity(0.90)
                              : Colors.black.withOpacity(0.88),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primary.withOpacity(isDark ? 0.95 : 0.90),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: isDark ? Colors.white54 : Colors.black45),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================
// Bookmark Tab
// =====================================================

class BookmarkTab extends StatefulWidget {
  final QuranArabicOnlyBundle quran;
  final BookmarkStore store;
  final Color primary;
  final void Function(int surahNo, int ayahNo) onOpen;

  const BookmarkTab({
    super.key,
    required this.quran,
    required this.store,
    required this.primary,
    required this.onOpen,
  });

  @override
  State<BookmarkTab> createState() => _BookmarkTabState();
}

class _BookmarkTabState extends State<BookmarkTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = widget.store.items;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'Tiada bookmark lagi.',
          style: TextStyle(
            fontSize: 16,
            color: isDark
                ? Colors.white.withOpacity(0.75)
                : Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
          height: 1,
          color:
              Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 1.0)),
        itemBuilder: (context, i) {
          final b = items[i];
          final surah =
          widget.quran.surahs.firstWhere((s) => s.number == b.surahNumber);
          final title = '${surah.displayNameEn} • Ayat ${b.ayahNumber}';
          final sub = _DateFmt.format(b.timestampMs);

          // Look up Arabic ayah text for preview
          QuranAyah? ayah;
          try {
            ayah = surah.ayahs.firstWhere((a) => a.ayahNumber == b.ayahNumber);
          } catch (_) {}
          final arabicText = ayah != null
              ? QuranTextSanitizer.removeBadCircleMarks(ayah.textWithEndSpan)
              : '';

          return ListTile(
            leading: OctaBadge(
                number: i + 1,
                size: 42,
                stroke: widget.primary.withOpacity(0.65)),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Colors.white.withOpacity(0.90)
                    : Colors.black.withOpacity(0.88),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (arabicText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    arabicText,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'KFGQPC',
                      fontSize: 18,
                      height: 1.6,
                      color: isDark
                          ? Colors.white.withOpacity(0.72)
                          : Colors.black.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  sub,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: widget.primary.withOpacity(isDark ? 0.95 : 0.90),
                  ),
                ),
              ],
            ),
            isThreeLine: arabicText.isNotEmpty,
            trailing: IconButton(
              tooltip: 'Padam',
              icon: Icon(Icons.delete_outline,
                  color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () async {
                await widget.store.removeAtIndex(i);
                if (!mounted) return;
                setState(() {});
              },
            ),
            onTap: () => widget.onOpen(b.surahNumber, b.ayahNumber),
          );
        },
      );
    }
  }

// =====================================================
// Timing models (for full-surah smooth playback)
// =====================================================

// =====================================================
// Surah Reader Page (FAST + ACCURATE JUMP)
// =====================================================

class SurahReaderPage extends StatefulWidget {
  final QuranSurah surah;
  final QuranArabicOnlyBundle quran;
  final LocalTranslationStore translations;
  final TajweedStore tajweed;
  final BookmarkStore bookmarks;
  final ReaderSettingsStore settingsStore;

  final String quranFontFamily;
  final String arabicTitleFamily;

  final int startAyah;

  const SurahReaderPage({
    super.key,
    required this.surah,
    required this.quran,
    required this.translations,
    required this.tajweed,
    required this.bookmarks,
    required this.settingsStore,
    required this.quranFontFamily,
    required this.arabicTitleFamily,
    required this.startAyah,
  });

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  // ScrollablePositionedList controllers — scroll to exact item positions.
  final ItemScrollController  _itemScrollController  = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();


  // ── User-scroll override ──────────────────────────────────────────────
  bool   _userScrolling = false;   // true while user is touching the list
  Timer? _resumeTimer;             // fires 3 s after last touch to resume

  int? _highlightAyah;

  // ── Per-ayah audio playback ────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAyah;
  bool _isLoadingAudio = false;

  Future<void> _togglePlay(int surahNo, int ayahNo) async {
    final id = surahNo * 1000 + ayahNo;
    if (_playingAyah == id) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() { _playingAyah = null; _isLoadingAudio = false; });
      return;
    }
    await _audioPlayer.stop();
    if (!mounted) return;
    setState(() { _playingAyah = id; _isLoadingAudio = true; });
    try {
      await _audioPlayer.play(UrlSource(
        QuranAudioService.instance.everyayahUrl(surahNo, ayahNo),
      ));
    } catch (_) {
      if (mounted) setState(() { _playingAyah = null; _isLoadingAudio = false; });
    }
  }
  // ── Full-surah smooth playback ─────────────────────────────────
  // Single just_audio player plays ONE downloaded full-surah MP3.
  // No per-ayah switching = perfectly smooth, identical to surahquran.com.
  // currentIndexStream drives verse highlight + scroll in the background.
  final ja.AudioPlayer _surahPlayer = ja.AudioPlayer();
  bool   _surahPlaying     = false;
  bool   _surahLoading     = false;
  int?   _surahCurrentAyah;
  double _surahVolume      = 1.0;
  // Tracks which reciter ID the current ConcatenatingAudioSource was built for.
  // If the user switches reciter, this won't match and we rebuild the playlist.
  int?   _loadedReciterId;
  // ── Per-ayah notes (SharedPreferences) ────────────────────────
  // Key: "quran_note_{surahNo}_{ayahNo}"  Value: note text
  Map<int, String> _notes = {}; // ayahNo → note text for current surah

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final surahNo = widget.surah.number;
    final fresh = <int, String>{};
    for (final ayah in widget.surah.ayahs) {
      final v = prefs.getString('quran_note_${surahNo}_${ayah.ayahNumber}');
      if (v != null && v.isNotEmpty) fresh[ayah.ayahNumber] = v;
    }
    if (mounted) setState(() => _notes = fresh);
  }

  Future<void> _saveNote(int ayahNo, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quran_note_${widget.surah.number}_$ayahNo';
    if (text.trim().isEmpty) {
      await prefs.remove(key);
      if (mounted) setState(() => _notes.remove(ayahNo));
    } else {
      await prefs.setString(key, text.trim());
      if (mounted) setState(() => _notes[ayahNo] = text.trim());
    }
  }
  // ───────────────────────────────────────────────────────────────


  String _everyayahUrl(int surahNo, int ayahNo) =>
      QuranAudioService.instance.everyayahUrl(surahNo, ayahNo);

  /// Pre-fetch verse timings in the background so they're ready when play is tapped.
  /// Does NOT download the audio file — that only happens when the user taps play.

  Future<void> _toggleSurahPlay() async {
    // Pause if already playing
    if (_surahPlaying) {
      await _surahPlayer.pause();
      if (mounted) setState(() => _surahPlaying = false);
      return;
    }

    // Stop per-ayah player if running
    if (_playingAyah != null) {
      await _audioPlayer.stop();
      if (mounted) setState(() { _playingAyah = null; _isLoadingAudio = false; });
    }

    // Resume if paused mid-surah AND the same reciter is still loaded
    final currentReciterId = QuranAudioService.instance.selectedReciter.id;
    if (_surahPlayer.processingState == ja.ProcessingState.ready &&
        _loadedReciterId == currentReciterId) {
      if (mounted) setState(() => _surahPlaying = true); // set BEFORE play()
      await _surahPlayer.play();
      // Snap scroll to current ayah and resume
      if (_surahCurrentAyah != null) {
        _scrollToAyah((_surahCurrentAyah! - 1), animate: false);
      }
      return;
    }

    // Fresh download + play
    await _startFullSurahPlayback();
  }

  Future<void> _startFullSurahPlayback() async {
    if (mounted) setState(() { _surahLoading = true; _surahPlaying = false; });

    try {
      final surahNo   = widget.surah.number;
      final ayahCount = widget.surah.ayahs.length;

      // Build gapless playlist — one MP3 per ayah via everyayah.com (selected reciter).
      // ConcatenatingAudioSource pre-buffers the next file, so playback is seamless.
      final reciter  = QuranAudioService.instance.selectedReciter;
      final children = List.generate(ayahCount, (i) {
        return ja.AudioSource.uri(
          Uri.parse(QuranAudioService.instance.everyayahUrl(surahNo, i + 1)),
        );
      });

      await _surahPlayer.setAudioSource(
        ja.ConcatenatingAudioSource(children: children),
        initialIndex:    0,
        initialPosition: Duration.zero,
      );

      if (mounted) setState(() {
        _surahLoading         = false;
        _surahPlaying         = true;
        _surahCurrentAyah     = 1;
        _loadedReciterId      = reciter.id;
      });

      await _surahPlayer.play();

      // Jump to surah header (item 0) so ayah 1 is visible immediately
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: 0);
      }

    } catch (e) {
      debugPrint('Full surah play failed: $e');
      if (mounted) {
        setState(() { _surahLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio error: $e')),
        );
      }
    }
  }


  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToAyah(widget.startAyah);
    });

    _loadNotes();
    // Load persisted reciter preference
    QuranAudioService.instance.loadSavedReciter();

    // Per-ayah single player: clear loading spinner once audio starts
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing && mounted) {
        setState(() => _isLoadingAudio = false);
      }
    });

    // Per-ayah play: one tap = one ayah, then stop.
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingAyah = null; _isLoadingAudio = false; });
    });

    // ── Full-surah just_audio listeners ─────────────────────────────────────
    //
    // currentIndexStream: fires the instant just_audio moves to the next ayah.
    // Perfect sync — no timing maths, no API, no drift.
    _surahPlayer.currentIndexStream.listen((index) {
      if (!mounted || index == null || !_surahPlaying) return;
      final ayahNo = index + 1; // convert 0-based index → 1-based ayah number
      if (ayahNo == _surahCurrentAyah) return;
      if (mounted) setState(() => _surahCurrentAyah = ayahNo);
      if (!_userScrolling) _scrollToAyah(index);
    });


    // playerStateStream: reset UI when surah finishes.
    _surahPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ja.ProcessingState.completed) {
        setState(() {
          _surahPlaying         = false;
          _surahCurrentAyah     = null;
        });
      }
    });
  }

  // ── Ayah 3-dot menu ───────────────────────────────────────────
  void _showAyahMenu(BuildContext ctx, int ayahNo) {
    final surahNo = widget.surah.number;
    final isDark  = Theme.of(ctx).brightness == Brightness.dark;

    // Gather text for copy/share
    final arabicText = widget.surah.ayahs
        .firstWhere((a) => a.ayahNumber == ayahNo)
        .textWithEndSpan
        .replaceAll(RegExp(r'<[^>]+>'), ''); // strip markup tags
    final translationText = widget.translations
        .translationFor(surahNumber: surahNo, ayahNumber: ayahNo, lang: TranslationLang.ms)
        .trim();
    final shareBody =
        '$arabicText\n\n$translationText\n\n— Surah ${widget.surah.displayNameEn}, Ayah $ayahNo';

    final existingNote = _notes[ayahNo] ?? '';
    final isPlayingThis = _playingAyah == (surahNo * 1000 + ayahNo);

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AyahMenuSheet(
        isDark: isDark,
        surahNo: surahNo,
        ayahNo: ayahNo,
        surahName: widget.surah.displayNameEn,
        isPlayingThis: isPlayingThis,
        existingNote: existingNote,
        onPlay: () {
          Navigator.pop(ctx);
          _togglePlay(surahNo, ayahNo);
        },
        onBookmark: () async {
          Navigator.pop(ctx);
          await HapticFeedback.mediumImpact();
          await widget.bookmarks.addOrCycle(
            surahNumber: surahNo,
            ayahNumber: ayahNo,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bookmark disimpan.')),
          );
        },
        onCopy: () {
          Navigator.pop(ctx);
          Clipboard.setData(ClipboardData(text: shareBody));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ayah disalin.')),
          );
        },
        onShare: () {
          Navigator.pop(ctx);
          Share.share(shareBody, subject: 'Surah ${widget.surah.displayNameEn} $ayahNo');
        },
        onNote: (String text) async {
          await _saveNote(ayahNo, text);
        },
      ),
    );
  }
  // ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _audioPlayer.dispose();
    _surahPlayer.dispose();
    super.dispose();
  }

  // ── User-scroll interaction ───────────────────────────────────────────

  /// Called when the user touches the list. Pauses auto-scroll immediately.
  void _onUserScrollStart() {
    if (!_surahPlaying) return;
    _resumeTimer?.cancel();
    if (!_userScrolling && mounted) setState(() => _userScrolling = true);
  }

  /// Called when the user lifts their finger. Schedules auto-scroll resume
  /// after 3 seconds of inactivity.
  void _onUserScrollEnd() {
    if (!_surahPlaying) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_surahPlaying) return;
      // Snap scroll to current ayah and resume tracking
      if (_surahCurrentAyah != null) {
        _scrollToAyah(_surahCurrentAyah! - 1, animate: false);
      }
      if (mounted) setState(() => _userScrolling = false);
    });
  }
  // ─────────────────────────────────────────────────────────────────────


  /// Scroll to a specific ayah and briefly highlight it.
  /// Uses a fraction-based estimate: ayahIndex / totalAyahs × maxScrollExtent.
  void _jumpToAyah(int ayahNo) {
    final safeAyah = ayahNo.clamp(1, widget.surah.ayahs.length);
    setState(() => _highlightAyah = safeAyah);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightAyah == safeAyah) {
        setState(() => _highlightAyah = null);
      }
    });
    _scrollToAyah(safeAyah - 1, animate: false);
  }

  /// Scroll so that the ayah at [index] (0-based) sits at ~35% from the top.
  /// ScrollablePositionedList measures real rendered item heights, so this is
  /// accurate for both short and long verses.
  ///
  /// Item 0 in the list is the surah header, so ayah index 0 → list item 1.
  void _scrollToAyah(int index, {bool animate = true}) {
    if (!_itemScrollController.isAttached) return;
    final listItem = index + 1; // offset by 1 for the surah header
    if (animate) {
      _itemScrollController.scrollTo(
        index:     listItem,
        alignment: 0.20,   // item top lands at 35% from viewport top
        duration:  const Duration(milliseconds: 600),
        curve:     Curves.easeInOutCubic,
      );
    } else {
      _itemScrollController.jumpTo(
        index:     listItem,
        alignment: 0.20,
      );
    }
  }

  // ── Download options ─────────────────────────────────────────────────────

  void _showDownloadOptions(BuildContext context, ColorScheme cs, bool isDark) {
    final primary = cs.primary;
    final surahNo = widget.surah.number;
    final surahName = widget.surah.displayNameEn;
    final ayahCount = widget.surah.ayahCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Muat Turun Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              '$surahName  •  $ayahCount ayat',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),

            // ── Option 1: Full Surah ──────────────────────────────
            _dlTile(
              isDark: isDark, cs: cs, primary: primary,
              icon: Icons.music_note_rounded,
              title: 'Muat Turun Surah Penuh',
              subtitle: 'Satu fail audio berterusan — tilawah sangat lancar tanpa '
                         'sebarang henti antara ayat. Disyor untuk bacaan.',
              badge: 'Disyor',
              onTap: () {
                Navigator.pop(context);
                // Download full surah via QuranAudioService
                _downloadFullSurah(surahNo, surahName);
              },
            ),
            const SizedBox(height: 12),

            // ── Option 2: Per Ayah ────────────────────────────────
            _dlTile(
              isDark: isDark, cs: cs, primary: primary,
              icon: Icons.format_list_numbered_rounded,
              title: 'Muat Turun Per Ayat',
              subtitle: 'Setiap ayat disimpan berasingan. '
                         'Sesuai untuk ulangan ayat tertentu atau hafazan.',
              badge: null,
              onTap: () {
                Navigator.pop(context);
                _downloadPerAyah(surahNo, surahName, ayahCount);
              },
            ),
            const SizedBox(height: 12),

            // Info note
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13,
                    color: cs.onSurface.withOpacity(0.38)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Audio disimpan dalam peranti dan tidak perlu dimuat turun semula.',
                    style: TextStyle(fontSize: 11,
                        color: cs.onSurface.withOpacity(0.4), height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dlTile({
    required bool isDark,
    required ColorScheme cs,
    required Color primary,
    required IconData icon,
    required String title,
    required String subtitle,
    required String? badge,
    required VoidCallback onTap,
  }) {
    final isRec = badge != null;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRec
              ? primary.withOpacity(isDark ? 0.14 : 0.07)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRec ? primary.withOpacity(0.35) : cs.onSurface.withOpacity(0.08),
            width: isRec ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: isRec ? primary.withOpacity(0.15) : cs.onSurface.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: isRec ? primary : cs.onSurface, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary, borderRadius: BorderRadius.circular(99)),
                        child: Text(badge,
                          style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    style: TextStyle(fontSize: 12,
                        color: cs.onSurface.withOpacity(0.55), height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  // ── Reciter picker bottom sheet ──────────────────────────────────────────
  void _showReciterPicker(BuildContext context, ColorScheme cs, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final primary = cs.primary;
          final selected = QuranAudioService.instance.selectedReciter;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              24, 16, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pilih Qari',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                      color: cs.onSurface),
                ),
                Text(
                  'Choose your preferred Quran reciter',
                  style: TextStyle(fontSize: 13,
                      color: cs.onSurface.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                ...kQuranReciters.map((reciter) {
                  final isActive = selected.id == reciter.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        // Stop any playing audio before switching reciter
                        if (_surahPlaying) _stopSurahPlay();
                        if (_playingAyah != null) {
                          await _audioPlayer.stop();
                          if (mounted) setState(() {
                            _playingAyah = null;
                            _isLoadingAudio = false;
                          });
                        }
                        await QuranAudioService.instance.setReciter(reciter);
                        setSheet(() {}); // refresh sheet
                        if (mounted) setState(() {}); // refresh page
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isActive
                              ? primary.withOpacity(isDark ? 0.15 : 0.08)
                              : (isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? primary.withOpacity(0.50)
                                : cs.onSurface.withOpacity(0.08),
                            width: isActive ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Active indicator circle
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive
                                      ? primary
                                      : cs.onSurface.withOpacity(0.25),
                                  width: isActive ? 5 : 1.5,
                                ),
                                color: isActive ? primary : Colors.transparent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reciter.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isActive
                                                ? primary
                                                : cs.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Icon(Icons.check_circle_rounded,
                                            color: primary, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reciter.nameAr,
                                    style: TextStyle(
                                      fontFamily: 'AmiriQuran',
                                      fontSize: 13,
                                      color: cs.onSurface.withOpacity(0.65),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${reciter.origin}  •  ${reciter.style}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withOpacity(0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13,
                        color: cs.onSurface.withOpacity(0.35)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Menukar qari akan menghenti semua audio yang sedang dimainkan.',
                        style: TextStyle(fontSize: 11,
                            color: cs.onSurface.withOpacity(0.40), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Stop full-surah playback (sync wrapper for GestureDetector.onTap) ──────
  void _stopSurahPlay() {
    _surahPlayer.stop().then((_) {
      if (mounted) {
        setState(() {
          _surahPlaying     = false;
          _surahCurrentAyah = null;
        });
      }
    });
  }

  // ── Seek to a specific 1-based ayah in the ConcatenatingAudioSource ─────
  Future<void> _seekToAyah(int ayahNo) async {
    final idx = (ayahNo - 1).clamp(0, widget.surah.ayahCount - 1);
    try {
      await _surahPlayer.seek(Duration.zero, index: idx);
      if (mounted) setState(() => _surahCurrentAyah = idx + 1);
    } catch (_) {}
  }

  // ── Duration → "m:ss" label ──────────────────────────────────────────────
  String _fmtDuration(Duration d) {
    if (d == Duration.zero) return '0:00';
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Volume control bottom sheet ──────────────────────────────────────────
  void _showVolumeControl(BuildContext ctx, ColorScheme cs) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelantangan Bunyi',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.volume_mute_rounded,
                        size: 20, color: cs.onSurface.withOpacity(0.45)),
                    Expanded(
                      child: Slider(
                        value: _surahVolume,
                        activeColor: cs.primary,
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _surahVolume = v);
                          _surahPlayer.setVolume(v);
                        },
                      ),
                    ),
                    Icon(Icons.volume_up_rounded,
                        size: 20, color: cs.onSurface.withOpacity(0.45)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadFullSurah(int surahNo, String surahName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memuat turun surah $surahName…')),
    );
    try {
      await QuranAudioService.instance.prepare(
        surahNo,
        onProgress: (p) {
          // Progress is shown via snackbar message; can enhance later
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ $surahName berjaya dimuat turun.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _downloadPerAyah(int surahNo, String surahName, int ayahCount) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memuat turun $ayahCount ayat $surahName…')),
    );
    try {
      await QuranAudioService.instance.downloadPerAyah(
        surahNumber: surahNo,
        ayahCount: ayahCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ $ayahCount ayat $surahName berjaya dimuat turun.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  // ── Surah header widget (item 0 in the list) ──────────────────────────────

  Widget _buildSurahHeader(BuildContext context, ColorScheme cs, bool isDark) {
    final primary    = cs.primary;
    final surah      = widget.surah;
    final showBismillah = surah.number != 9 && surah.number != 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: isDark
              ? [primary.withOpacity(0.18), primary.withOpacity(0.08)]
              : [primary.withOpacity(0.13), primary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(isDark ? 0.2 : 0.18)),
      ),
      child: Column(
        children: [
          // Arabic surah name
          Text(
            surah.nameAr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize:   42,
              color:      primary,
              height:     1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${surah.number}. ${surah.displayNameEn}',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900, color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${surah.ayahCount} Ayat',
            style: TextStyle(
              fontSize: 13, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w600,
            ),
          ),
          if (showBismillah) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: primary.withOpacity(0.25))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.5), shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: primary.withOpacity(0.25))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign:     TextAlign.center,
              style: TextStyle(
                fontFamily: 'KFGQPC',
                fontSize:   24,
                color:      cs.onSurface,
                height:     2.0,
              ),
            ),
            Text(
              'Dengan Nama Allah Yang Maha Pengasih lagi Maha Penyayang',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:  12, fontStyle: FontStyle.italic,
                color:     cs.onSurface.withOpacity(0.58), height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom audio bar (quran.com style) ───────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ColorScheme cs, bool isDark) {
    final primary  = cs.primary;
    final barColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final isActive = _surahCurrentAyah != null || _surahPlaying || _surahLoading;

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withOpacity(isDark ? 0.28 : 0.07),
            blurRadius: 14, offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Info row: surah + ayah count ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isActive
                              ? '${widget.surah.displayNameEn}  •  Ayat '
                                '${_surahCurrentAyah ?? '-'} / '
                                '${widget.surah.ayahCount}'
                              : widget.surah.displayNameEn,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: isActive ? primary : cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'As-Sudais – Murattal',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Control buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  // More / Download options
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded,
                        color: cs.onSurface.withOpacity(0.55)),
                    onPressed: () =>
                        _showDownloadOptions(context, cs, isDark),
                    tooltip:     'Pilihan',
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 40, minHeight: 40),
                  ),

                  // Volume
                  IconButton(
                    icon: Icon(
                      _surahVolume < 0.01
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                    onPressed: () =>
                        _showVolumeControl(context, cs),
                    tooltip:     'Kelantangan',
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 40, minHeight: 40),
                  ),

                  // Skip to previous ayah
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded,
                        size: 32,
                        color: isActive
                            ? cs.onSurface.withOpacity(0.70)
                            : cs.onSurface.withOpacity(0.25)),
                    onPressed: isActive
                        ? () {
                            final prev =
                                (_surahCurrentAyah ?? 2) - 1;
                            if (prev >= 1) _seekToAyah(prev);
                          }
                        : null,
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 44, minHeight: 44),
                  ),

                  // Play / Pause (primary circle button)
                  GestureDetector(
                    onTap: _toggleSurahPlay,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color:  primary,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:      primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _surahLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              _surahPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white, size: 28,
                            ),
                    ),
                  ),

                  // Skip to next ayah
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded,
                        size: 32,
                        color: isActive
                            ? cs.onSurface.withOpacity(0.70)
                            : cs.onSurface.withOpacity(0.25)),
                    onPressed: isActive
                        ? () {
                            final next =
                                (_surahCurrentAyah ?? 0) + 1;
                            if (next <= widget.surah.ayahCount)
                              _seekToAyah(next);
                          }
                        : null,
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 44, minHeight: 44),
                  ),

                  // Stop / Close
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isActive
                            ? cs.onSurface.withOpacity(0.70)
                            : cs.onSurface.withOpacity(0.25)),
                    onPressed: isActive ? _stopSurahPlay : null,
                    tooltip:     'Henti',
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 40, minHeight: 40),
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ── Reader settings ───────────────────────────────────────────────────────

  // ✅ Realtime settings: sheet updates store directly
  Future<void> _openReaderSettings(BuildContext context, bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ReaderSettingsSheet(isDark: isDark, store: widget.settingsStore),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.settingsStore,
      builder: (context, _) {
        final s = widget.settingsStore.value;

        return Scaffold(
          bottomNavigationBar: _buildBottomBar(context, cs, isDark),
          appBar: AppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            // FittedBox scales the title text down to fit the available
            // width — never truncates, no matter how many action buttons exist.
            title: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.surah.number}. ${widget.surah.displayNameEn}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Cari / Lompat',
                icon: const Icon(Icons.search),
                onPressed: () async {
                  final result = await showModalBottomSheet<_JumpResult>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _SearchSheet(quran: widget.quran),
                  );
                  if (!mounted || result == null) return;

                  if (result.surahNumber != widget.surah.number) {
                    final s2 = widget.quran.surahs
                        .firstWhere((x) => x.number == result.surahNumber);

                    if (!mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahReaderPage(
                          tajweed: widget.tajweed,
                          surah: s2,
                          quran: widget.quran,
                          translations: widget.translations,
                          bookmarks: widget.bookmarks,
                          settingsStore: widget.settingsStore,
                          quranFontFamily: widget.quranFontFamily,
                          arabicTitleFamily: widget.arabicTitleFamily,
                          startAyah: result.ayahNumber,
                        ),
                      ),
                    );
                  } else {
                    _jumpToAyah(result.ayahNumber);
                  }
                },
              ),
              IconButton(
                tooltip: 'Pilih Qari',
                icon: const Icon(Icons.record_voice_over_rounded),
                onPressed: () => _showReciterPicker(context, cs, isDark),
              ),
              IconButton(
                tooltip: 'Tetapan Bacaan',
                icon: const Icon(Icons.tune),
                onPressed: () => _openReaderSettings(context, isDark),
              ),
            ],
          ),
          body: Stack(
            children: [
              // ── Verse list (wrapped in Listener for touch-to-pause) ─
              Listener(
                onPointerDown: (_) => _onUserScrollStart(),
                onPointerUp:   (_) => _onUserScrollEnd(),
                onPointerCancel: (_) => _onUserScrollEnd(),
                child: ScrollablePositionedList.separated(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            padding: const EdgeInsets.only(bottom: 24),
            // +1 for the surah header at index 0
            itemCount: widget.surah.ayahs.length + 1,
            separatorBuilder: (_, i) {
              // No separator after the header (it has its own margin)
              if (i == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: cs.onSurface.withOpacity(isDark ? 0.07 : 0.06),
                ),
              );
            },
            itemBuilder: (context, i) {
              // ── Item 0: beautiful surah header ──────────────────
              if (i == 0) return _buildSurahHeader(context, cs, isDark);

              // ── Items 1…n: verse cards ───────────────────────────
              final ayah    = widget.surah.ayahs[i - 1];
              final ayahNo  = ayah.ayahNumber;
              final surahNo = widget.surah.number;

              final cleaned =
                  QuranTextSanitizer.removeBadCircleMarks(ayah.textWithEndSpan);

              final isHighlighted = (_highlightAyah == ayahNo) ||
                  (_surahCurrentAyah == ayahNo);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () async {
                  await HapticFeedback.heavyImpact();
                  await widget.bookmarks.addOrCycle(
                    surahNumber: surahNo,
                    ayahNumber:  ayahNo,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark disimpan.')),
                  );
                },
                child: AyahCard(
                  isDark:                isDark,
                  highlight:             isHighlighted,
                  arabicMarkup:          QuranTextSanitizer.removeBadCircleMarks(
                    widget.tajweed.textFor(surahNumber: surahNo, ayahNumber: ayahNo) ?? cleaned,
                  ),
                  quranFontFamily:       widget.quranFontFamily,
                  arabicFontSize:        s.arabicFontSize,
                  arabicLineHeight:      s.arabicLineHeight,
                  showTranslation:       s.showTranslation,
                  translationLang:       s.translationLang,
                  translationStore:      widget.translations,
                  surahNumber:           surahNo,
                  ayahNumber:            ayahNo,
                  translationFontSize:   s.translationFontSize,
                  translationLineHeight: s.translationLineHeight,
                  isPlaying:             (_playingAyah == (surahNo * 1000 + ayahNo) && !_isLoadingAudio)
                                             || (_surahPlaying && _surahCurrentAyah == ayahNo),
                  isLoadingAudio:        _playingAyah == (surahNo * 1000 + ayahNo) && _isLoadingAudio,
                  onPlayTap:             () => _togglePlay(surahNo, ayahNo),
                  highlightedWordIndex:  null,
                  hasNote:               _notes.containsKey(ayahNo),
                  onMoreTap:             () => _showAyahMenu(context, ayahNo),
                ),
              );
            },
          ),
              ), // ── end Listener ──────────────────────────────────────


              // ── "Back to verse" FAB ────────────────────────────────
              // Appears while the user is scrolling freely during playback.
              // Tapping it snaps back to the current recitation position.
              if (_userScrolling && _surahPlaying)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _resumeTimer?.cancel();
                        if (_surahCurrentAyah != null) {
                          _scrollToAyah(_surahCurrentAyah! - 1, animate: true);
                        }
                        if (mounted) setState(() => _userScrolling = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.82)
                              : Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Back to verse',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================
// Ornate verse-number badge (quran.com style)
// =====================================================

String _toArabicNum(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}


// =====================================================
// Ayah Card
// =====================================================

class AyahCard extends StatelessWidget {
  final bool isDark;
  final bool highlight;
  final String arabicMarkup;
  final String quranFontFamily;

  final double arabicFontSize;
  final double arabicLineHeight;

  final bool showTranslation;
  final TranslationLang translationLang;
  final LocalTranslationStore translationStore;
  final int surahNumber;
  final int ayahNumber;

  final double translationFontSize;
  final double translationLineHeight;

  // ── Audio ──────────────────────────────────────────────────────
  final bool isPlaying;
  final bool isLoadingAudio;
  final VoidCallback onPlayTap;
  final int? highlightedWordIndex;
  // ── Menu ───────────────────────────────────────────────────────
  final bool hasNote;
  final VoidCallback onMoreTap;
  // ───────────────────────────────────────────────────────────────

  const AyahCard({
    super.key,
    required this.isDark,
    required this.highlight,
    required this.arabicMarkup,
    required this.quranFontFamily,
    required this.arabicFontSize,
    required this.arabicLineHeight,
    required this.showTranslation,
    required this.translationLang,
    required this.translationStore,
    required this.surahNumber,
    required this.ayahNumber,
    required this.translationFontSize,
    required this.translationLineHeight,
    required this.isPlaying,
    required this.isLoadingAudio,
    required this.onPlayTap,
    this.highlightedWordIndex,
    this.hasNote = false,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final primary = cs.primary;

    // Quran.com style: NO card border, just a subtle highlight when playing
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      // Subtle background when this verse is highlighted (playing or jumped to)
      color: highlight
          ? primary.withOpacity(isDark ? 0.09 : 0.06)
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verse header row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                // Verse number (tap = play this ayah)
                GestureDetector(
                  onTap: onPlayTap,
                  child: Text(
                    ayahNumber.toString(),
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      isPlaying ? primary : primary.withOpacity(0.70),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Verse reference: "55:1"
                Text(
                  '$surahNumber:$ayahNumber',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color: highlight ? primary : cs.onSurface.withOpacity(0.55),
                  ),
                ),

                // Playing equalizer icon
                if (isPlaying) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.graphic_eq_rounded, size: 16, color: primary),
                ],
                if (isLoadingAudio) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: primary,
                    ),
                  ),
                ],

                const Spacer(),

                // Note indicator
                if (hasNote)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.edit_note_rounded,
                        size: 16, color: primary.withOpacity(0.65)),
                  ),

                // Action buttons: play, more
                _actionBtn(
                  icon:  isPlaying ? Icons.stop_rounded : Icons.play_circle_outline_rounded,
                  color: cs.onSurface.withOpacity(0.45),
                  onTap: onPlayTap,
                ),
                _actionBtn(
                  icon:  Icons.more_horiz_rounded,
                  color: cs.onSurface.withOpacity(0.40),
                  onTap: onMoreTap,
                ),
              ],
            ),
          ),

          // ── Arabic text — large, centered, RTL ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: TajwidRichText(
              key: ValueKey(
                'ar_${surahNumber}_${ayahNumber}_'
                '${arabicFontSize.toStringAsFixed(1)}_'
                '${arabicLineHeight.toStringAsFixed(2)}_'
                '$highlightedWordIndex',
              ),
              tajwidMarkup:        arabicMarkup,
              fontFamily:          quranFontFamily,
              fontSize:            arabicFontSize,
              height:              arabicLineHeight,
              textAlign:           TextAlign.center,
              enableColors:        true,
              highlightedWordIndex: highlightedWordIndex,
            ),
          ),

          // ── Malay translation — left aligned ─────────────────────────────
          if (showTranslation)
            Builder(
              builder: (context) {
                final t = translationStore
                    .translationFor(
                      surahNumber: surahNumber,
                      ayahNumber:  ayahNumber,
                      lang:        translationLang,
                    )
                    .trim();

                if (t.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
                  child: Text(
                    t,
                    key: ValueKey(
                        'tr_${surahNumber}_${ayahNumber}_${translationLang.name}'),
                    textAlign: TextAlign.left,   // ← left-aligned like quran.com
                    style: TextStyle(
                      fontSize:   translationFontSize,
                      height:     translationLineHeight,
                      color:      isDark
                          ? Colors.white.withOpacity(0.82)
                          : Colors.black.withOpacity(0.78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),

          // ── Tafsir / Renungan links ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                _linkBtn(context, Icons.menu_book_outlined, 'Tafsir', cs),
                Text(' | ', style: TextStyle(color: cs.onSurface.withOpacity(0.18))),
                _linkBtn(context, Icons.lightbulb_outline_rounded, 'Renungan', cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36, height: 36,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _linkBtn(BuildContext context, IconData icon, String label, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.35)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.35),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// Ayah 3-dot Menu Sheet
// =====================================================

class _AyahMenuSheet extends StatefulWidget {
  final bool isDark;
  final int surahNo;
  final int ayahNo;
  final String surahName;
  final bool isPlayingThis;
  final String existingNote;
  final VoidCallback onPlay;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final Future<void> Function(String) onNote;

  const _AyahMenuSheet({
    required this.isDark,
    required this.surahNo,
    required this.ayahNo,
    required this.surahName,
    required this.isPlayingThis,
    required this.existingNote,
    required this.onPlay,
    required this.onBookmark,
    required this.onCopy,
    required this.onShare,
    required this.onNote,
  });

  @override
  State<_AyahMenuSheet> createState() => _AyahMenuSheetState();
}

class _AyahMenuSheetState extends State<_AyahMenuSheet> {
  bool _showNoteInput = false;
  late final TextEditingController _noteCtl;

  @override
  void initState() {
    super.initState();
    _noteCtl = TextEditingController(text: widget.existingNote);
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  widget.surahName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Ayah ${widget.ayahNo}',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16, indent: 20, endIndent: 20),

          if (!_showNoteInput) ...[
            // Action tiles
            _MenuTile(
              isDark: isDark,
              icon: widget.isPlayingThis ? Icons.stop_rounded : Icons.play_arrow_rounded,
              iconColor: Colors.green,
              label: widget.isPlayingThis ? 'Stop' : 'Play ayah',
              onTap: widget.onPlay,
            ),
            _MenuTile(
              isDark: isDark,
              icon: Icons.bookmark_add_outlined,
              iconColor: Colors.orange,
              label: 'Bookmark',
              onTap: widget.onBookmark,
            ),
            _MenuTile(
              isDark: isDark,
              icon: Icons.copy_rounded,
              iconColor: Colors.blue,
              label: 'Copy ayah',
              onTap: widget.onCopy,
            ),
            _MenuTile(
              isDark: isDark,
              icon: Icons.share_rounded,
              iconColor: Colors.purple,
              label: 'Share',
              onTap: widget.onShare,
            ),
            _MenuTile(
              isDark: isDark,
              icon: widget.existingNote.isEmpty
                  ? Icons.edit_note_rounded
                  : Icons.sticky_note_2_outlined,
              iconColor: Colors.teal,
              label: widget.existingNote.isEmpty ? 'Add note' : 'Edit note',
              onTap: () => setState(() => _showNoteInput = true),
            ),
          ] else ...[
            // Note input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _noteCtl,
                autofocus: true,
                maxLines: 4,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Write your note here…',
                  hintStyle: TextStyle(color: subColor),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _showNoteInput = false),
                      child: Text('Cancel', style: TextStyle(color: subColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await widget.onNote(_noteCtl.text);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withOpacity(0.87) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Search / Jump Sheet
// =====================================================

class _SearchSheet extends StatefulWidget {
  final QuranArabicOnlyBundle quran;
  const _SearchSheet({required this.quran});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _surahCtl = TextEditingController();
  final _ayahCtl = TextEditingController();
  String _surahNamePreview = '';

  @override
  void initState() {
    super.initState();
    _surahCtl.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _surahCtl.removeListener(_updatePreview);
    _surahCtl.dispose();
    _ayahCtl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final s = int.tryParse(_surahCtl.text.trim());
    if (s == null || s < 1 || s > 114) {
      if (_surahNamePreview.isNotEmpty) setState(() => _surahNamePreview = '');
      return;
    }
    final name =
        widget.quran.surahs.firstWhere((x) => x.number == s).displayNameEn;
    if (name != _surahNamePreview) setState(() => _surahNamePreview = name);
  }

  void _go() {
    final s = int.tryParse(_surahCtl.text.trim());
    final a = int.tryParse(_ayahCtl.text.trim());

    final surah = (s == null) ? 1 : s.clamp(1, 114);
    final ayah = (a == null) ? 1 : a.clamp(1, 999);

    Navigator.pop(context, _JumpResult(surahNumber: surah, ayahNumber: ayah));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.70),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cari / Lompat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white.withOpacity(0.92)
                          : Colors.black.withOpacity(0.86),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _surahCtl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Surah (1–114)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _ayahCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Ayah'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _go,
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                        ),
                        child: const Text('Go'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _surahNamePreview.isEmpty
                                ? 'Masukkan nombor surah untuk lihat nama.'
                                : _surahNamePreview,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white.withOpacity(0.88)
                                  : Colors.black.withOpacity(0.80),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpResult {
  final int surahNumber;
  final int ayahNumber;
  _JumpResult({required this.surahNumber, required this.ayahNumber});
}

// =====================================================
// Reader Settings
// =====================================================

enum TranslationLang { ms, en }

class ReaderSettings {
  double arabicFontSize;
  double arabicLineHeight;
  bool showTranslation;
  TranslationLang translationLang;
  double translationFontSize;
  double translationLineHeight;

  ReaderSettings({
    required this.arabicFontSize,
    required this.arabicLineHeight,
    required this.showTranslation,
    required this.translationLang,
    required this.translationFontSize,
    required this.translationLineHeight,
  });

  ReaderSettings copy() => ReaderSettings(
        arabicFontSize: arabicFontSize,
        arabicLineHeight: arabicLineHeight,
        showTranslation: showTranslation,
        translationLang: translationLang,
        translationFontSize: translationFontSize,
        translationLineHeight: translationLineHeight,
      );

  Map<String, dynamic> toJson() => {
        'arabicFontSize': arabicFontSize,
        'arabicLineHeight': arabicLineHeight,
        'showTranslation': showTranslation,
        'translationLang': translationLang.name,
        'translationFontSize': translationFontSize,
        'translationLineHeight': translationLineHeight,
      };

  static ReaderSettings fromJson(Map<String, dynamic> j) {
    final langStr = (j['translationLang'] ?? 'ms').toString();
    final lang = (langStr == 'en') ? TranslationLang.en : TranslationLang.ms;
    return ReaderSettings(
      arabicFontSize: (j['arabicFontSize'] as num?)?.toDouble() ?? 34.0,
      arabicLineHeight: (j['arabicLineHeight'] as num?)?.toDouble() ?? 1.60,
      showTranslation: (j['showTranslation'] as bool?) ?? true,
      translationLang: lang,
      translationFontSize:
          (j['translationFontSize'] as num?)?.toDouble() ?? 16.0,
      translationLineHeight:
          (j['translationLineHeight'] as num?)?.toDouble() ?? 1.35,
    );
  }
}

class ReaderSettingsStore extends ChangeNotifier {
  static const String _prefsKey = 'reader_settings_v1';

  ReaderSettings _value = ReaderSettings(
    arabicFontSize: 34.0,
    arabicLineHeight: 1.60,
    showTranslation: true,
    translationLang: TranslationLang.ms,
    translationFontSize: 16.0,
    translationLineHeight: 1.35,
  );

  ReaderSettings get value => _value;

  Timer? _debounce;

  Future<void> load() async {
    final prefs = PrefsService.instance;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        _value = ReaderSettings.fromJson(decoded);
        notifyListeners();
      }
    } catch (_) {}
  }

  // Keep original save (if you still want to use it somewhere else)
  Future<void> save(ReaderSettings v) async {
    _value = v;
    notifyListeners();
    final prefs = PrefsService.instance;
    await prefs.setString(_prefsKey, json.encode(v.toJson()));
  }

  // ✅ Realtime update + debounce autosave
  void update(void Function(ReaderSettings s) mutate) {
    mutate(_value);
    notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final prefs = PrefsService.instance;
      await prefs.setString(_prefsKey, json.encode(_value.toJson()));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class _ReaderSettingsSheet extends StatelessWidget {
  final bool isDark;
  final ReaderSettingsStore store;

  const _ReaderSettingsSheet({
    required this.isDark,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: screenHeight * 0.42, // ✅ smaller than 50%
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), // ✅ tighter
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.10),
                ),
              ),
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) {
                  final s = store.value;

                  return ScrollConfiguration(
                    behavior: const _NoGlowScrollBehavior(),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // drag handle (smaller)
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          _label(isDark,
                              'Saiz Arab: ${s.arabicFontSize.toStringAsFixed(0)}'),
                          _compactSlider(
                            context,
                            value: s.arabicFontSize,
                            min: 22,
                            max: 48,
                            divisions: 26,
                            onChanged: (v) =>
                                store.update((x) => x.arabicFontSize = v),
                          ),

                          _label(isDark,
                              'Line Arab: ${s.arabicLineHeight.toStringAsFixed(2)}'),
                          _compactSlider(
                            context,
                            value: s.arabicLineHeight,
                            min: 1.10,
                            max: 2.30,
                            divisions: 24,
                            onChanged: (v) =>
                                store.update((x) => x.arabicLineHeight = v),
                          ),

                          const SizedBox(height: 2),

                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(
                                horizontal: -2, vertical: -2), // ✅ tighter
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            value: s.showTranslation,
                            onChanged: (v) =>
                                store.update((x) => x.showTranslation = v),
                            title: Text(
                              'Papar Terjemahan',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withOpacity(0.90)
                                    : Colors.black.withOpacity(0.85),
                              ),
                            ),
                          ),

                          if (s.showTranslation) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 38, // ✅ smaller segmented control
                              child: SegmentedButton<TranslationLang>(
                                segments: const [
                                  ButtonSegment(
                                      value: TranslationLang.ms,
                                      label: Text('BM')),
                                  ButtonSegment(
                                      value: TranslationLang.en,
                                      label: Text('EN')),
                                ],
                                selected: {s.translationLang},
                                onSelectionChanged: (set) => store.update(
                                    (x) => x.translationLang = set.first),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _label(isDark,
                                'Saiz Terjemahan: ${s.translationFontSize.toStringAsFixed(0)}'),
                            _compactSlider(
                              context,
                              value: s.translationFontSize,
                              min: 12,
                              max: 24,
                              divisions: 12,
                              onChanged: (v) => store
                                  .update((x) => x.translationFontSize = v),
                            ),
                            _label(isDark,
                                'Line Terjemahan: ${s.translationLineHeight.toStringAsFixed(2)}'),
                            _compactSlider(
                              context,
                              value: s.translationLineHeight,
                              min: 1.10,
                              max: 1.80,
                              divisions: 14,
                              onChanged: (v) => store
                                  .update((x) => x.translationLineHeight = v),
                            ),
                          ],

                          const SizedBox(height: 6),

                          SizedBox(
                            height: 40, // ✅ smaller button
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Tutup'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _label(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.5, // ✅ smaller label
          color: isDark
              ? Colors.white.withOpacity(0.82)
              : Colors.black.withOpacity(0.72),
        ),
      ),
    );
  }

  static Widget _compactSlider(
    BuildContext context, {
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.2, // ✅ thinner track
        overlayShape: SliderComponentShape.noOverlay, // ✅ remove big halo
        thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7), // ✅ smaller thumb
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

// ✅ remove scroll glow
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

// =====================================================
// Octagon/Star badge
// =====================================================

class OctaBadge extends StatelessWidget {
  final int number;
  final double size;
  final Color stroke;

  const OctaBadge({
    super.key,
    required this.number,
    required this.size,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    final innerText = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(stroke: stroke),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: size * 0.30,
              fontWeight: FontWeight.w900,
              color: innerText,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color stroke;
  _StarPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final outerR = math.min(size.width, size.height) * 0.48;
    final innerR = outerR * 0.72;

    final path = Path();
    for (int i = 0; i < 16; i++) {
      final isOuter = i.isEven;
      final r = isOuter ? outerR : innerR;
      final a = (-math.pi / 2) + (i * (math.pi / 8));
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

// =====================================================
// Bookmarks
// =====================================================

class BookmarkItem {
  final int slot;
  final int surahNumber;
  final int ayahNumber;
  final int timestampMs;

  BookmarkItem({
    required this.slot,
    required this.surahNumber,
    required this.ayahNumber,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'surah': surahNumber,
        'ayah': ayahNumber,
        'ts': timestampMs,
      };

  static BookmarkItem fromJson(Map<String, dynamic> j) {
    return BookmarkItem(
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      surahNumber: (j['surah'] as num?)?.toInt() ?? 1,
      ayahNumber: (j['ayah'] as num?)?.toInt() ?? 1,
      timestampMs:
          (j['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class BookmarkStore {
  static const _prefsKey = 'bookmarks_v2';
  static const _max = 20;

  final List<BookmarkItem> items = [];
  int _nextSlot = 0;

  Future<void> load() async {
    items.clear();
    final prefs = PrefsService.instance;
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        _nextSlot = (decoded['nextSlot'] as num?)?.toInt() ?? 0;
        final list = decoded['items'];
        if (list is List) {
          for (final it in list) {
            if (it is Map<String, dynamic>)
              items.add(BookmarkItem.fromJson(it));
          }
        }
      }
      items.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
      _nextSlot = _nextSlot % _max;
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = PrefsService.instance;
    final payload = {
      'nextSlot': _nextSlot,
      'items': items.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_prefsKey, json.encode(payload));
  }

  Future<void> addOrCycle(
      {required int surahNumber, required int ayahNumber}) async {
    final slot = _nextSlot % _max;
    _nextSlot = (_nextSlot + 1) % _max;

    items.removeWhere((x) => x.slot == slot);

    items.add(
      BookmarkItem(
        slot: slot,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    items.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    await _save();
  }

  Future<void> removeAtIndex(int index) async {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    await _save();
  }
}

// =====================================================
// Local translations (same as yours)
// =====================================================

class LocalTranslationStore {
  final Map<String, String> _ms;
  final Map<String, String> _en;

  LocalTranslationStore._(this._ms, this._en);

  int get debugCountMs => _ms.length;
  int get debugCountEn => _en.length;

  static String _normKey(String k) {
    var s = k.trim();
    s = s.replaceAll('|', ':').replaceAll('_', ':').replaceAll('-', ':');
    s = s.replaceAll(RegExp(r'\s*:\s*'), ':');
    return s;
  }

  static Map<String, String> _mapFromSequentialList(
      QuranArabicOnlyBundle quran, List list, String label) {
    final out = <String, String>{};

    final strings = <String>[];
    for (final x in list) {
      if (x is String)
        strings.add(x);
      else if (x is num)
        strings.add(x.toString());
      else if (x != null) strings.add(x.toString());
    }
    if (strings.isEmpty) return out;

    int idx = 0;
    for (final s in quran.surahs) {
      for (final a in s.ayahs) {
        if (idx >= strings.length) break;
        final t = strings[idx].trim();
        if (t.isNotEmpty) out['${s.number}:${a.ayahNumber}'] = t;
        idx++;
      }
      if (idx >= strings.length) break;
    }

    debugPrint(
        '✅ [$label] sequential list mapped => ${out.length} entries (input=${strings.length})');
    return out;
  }

  static Future<LocalTranslationStore> loadWithQuran({
    required QuranArabicOnlyBundle quran,
    required String msPath,
    required String enPath,
  }) async {
    final msRaw = await rootBundle.loadString(msPath);
    final enRaw = await rootBundle.loadString(enPath);

    final ms = _parseAny(msRaw, label: 'ms.json', quran: quran);
    final en = _parseAny(enRaw, label: 'en.json', quran: quran);

    debugPrint('✅ Translation maps final: MS=${ms.length}, EN=${en.length}');
    return LocalTranslationStore._(ms, en);
  }

  String translationFor({
    required int surahNumber,
    required int ayahNumber,
    required TranslationLang lang,
  }) {
    final key = '$surahNumber:$ayahNumber';
    final map = (lang == TranslationLang.en) ? _en : _ms;

    final direct = map[key];
    if (direct != null && direct.trim().isNotEmpty) return direct;

    for (final k in <String>[
      '$surahNumber|$ayahNumber',
      '${surahNumber}_$ayahNumber',
      '$surahNumber-$ayahNumber',
    ]) {
      final v = map[_normKey(k)];
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  static Map<String, String> _parseAny(
    String raw, {
    required String label,
    required QuranArabicOnlyBundle quran,
  }) {
    try {
      final decoded = json.decode(raw);

      if (decoded is List) {
        final sample =
            decoded.take(decoded.length < 20 ? decoded.length : 20).toList();
        final stringCount = sample.whereType<String>().length;
        final isMostlyString =
            sample.isNotEmpty && (stringCount / sample.length) >= 0.6;
        if (isMostlyString) {
          return _mapFromSequentialList(quran, decoded, label);
        }
      }

      final out = <String, String>{};

      void putKV(String k, String v) {
        final kk = _normKey(k);
        final vv = v.trim();
        if (kk.isEmpty || vv.isEmpty) return;
        out[kk] = vv;
      }

      void extract(dynamic node, {int? currentSurah}) {
        if (node == null) return;

        if (node is Map<String, dynamic>) {
          final looksLikeVerseKeyMap = node.keys.any((k) {
            final s = k.toString();
            return s.contains(':') ||
                s.contains('|') ||
                s.contains('_') ||
                s.contains('-');
          });

          if (looksLikeVerseKeyMap) {
            for (final e in node.entries) {
              putKV(e.key.toString(), (e.value ?? '').toString());
            }
            return;
          }

          for (final key in const [
            'quran',
            'data',
            'result',
            'translations',
            'surahs',
            'verses',
            'items'
          ]) {
            if (node.containsKey(key)) {
              extract(node[key], currentSurah: currentSurah);
            }
          }

          final verseKey =
              (node['verse_key'] ?? node['verseKey'] ?? node['ayah_key'] ?? '')
                  .toString()
                  .trim();
          if (verseKey.isNotEmpty) {
            final text = (node['text'] ??
                    node['translation'] ??
                    node['translate'] ??
                    node['meaning'] ??
                    '')
                .toString();
            putKV(verseKey, text);
            return;
          }

          final sVal = node['sura'] ??
              node['surah'] ??
              node['chapter'] ??
              node['id'] ??
              node['s'];
          final aVal =
              node['aya'] ?? node['ayah'] ?? node['verse'] ?? node['a'];
          final sn = int.tryParse('$sVal');
          final an = int.tryParse('$aVal');
          final t = (node['translation'] ??
                  node['text'] ??
                  node['translate'] ??
                  node['meaning'] ??
                  '')
              .toString()
              .trim();
          if (sn != null && an != null && t.isNotEmpty) {
            putKV('$sn:$an', t);
            return;
          }

          for (final key in const ['aya', 'ayah', 'ayahs', 'verses', 'items']) {
            if (node.containsKey(key)) {
              extract(node[key], currentSurah: sn ?? currentSurah);
            }
          }
          return;
        }

        if (node is List) {
          for (final item in node) extract(item, currentSurah: currentSurah);
        }
      }

      extract(decoded);
      debugPrint('✅ Parsed $label => ${out.length} entries');
      return out;
    } catch (e) {
      debugPrint('❌ Failed parsing $label: $e');
      return {};
    }
  }
}

// =====================================================
// Quran loader (xml) (same as yours)
// =====================================================

class QuranArabicOnlyBundle {
  final List<QuranSurah> surahs;
  QuranArabicOnlyBundle({required this.surahs});
}

class QuranSurah {
  final int number;
  final String nameAr;
  final String displayNameEn;
  final String revelationLabel;
  final int ayahCount;
  final List<QuranAyah> ayahs;

  QuranSurah({
    required this.number,
    required this.nameAr,
    required this.displayNameEn,
    required this.revelationLabel,
    required this.ayahCount,
    required this.ayahs,
  });
}

class QuranAyah {
  final int ayahNumber;
  final String textWithEndSpan;

  QuranAyah({required this.ayahNumber, required this.textWithEndSpan});
}

class QuranLoader {
  static const Set<int> _makkiSet = {
    1,
    6,
    7,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    23,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
  };

  static Future<QuranArabicOnlyBundle> loadArabicOnly(
      {required String uthmaniXmlPath}) async {
    final xmlString = await rootBundle.loadString(uthmaniXmlPath);
    final doc = XmlDocument.parse(xmlString);

    final quran = doc.findAllElements('quran').first;
    final suraNodes = quran.findAllElements('sura').toList();
    if (suraNodes.isEmpty)
      throw Exception('No <sura> nodes found in $uthmaniXmlPath');

    final surahs = <QuranSurah>[];

    for (final s in suraNodes) {
      final number =
          int.tryParse(s.getAttribute('index') ?? '') ?? (surahs.length + 1);
      final nameAr = (s.getAttribute('name') ?? '').trim();

      final nameEnRaw = (s.getAttribute('tname') ?? 'Surah $number').trim();
      final displayNameEn = _normalizeSurahName(nameEnRaw, number);

      final isMakki = _makkiSet.contains(number);
      final revelationLabel = isMakki ? 'MEKAH' : 'MADINAH';

      final ayahs = <QuranAyah>[];
      for (final a in s.findAllElements('aya')) {
        final ayahNo =
            int.tryParse(a.getAttribute('index') ?? '') ?? (ayahs.length + 1);
        final rawText = (a.getAttribute('text') ?? '').trim();
        if (rawText.isEmpty) continue;

        final withEnd =
            '$rawText <span class=end>${_toArabicIndicDigits(ayahNo)}</span>';
        ayahs.add(QuranAyah(ayahNumber: ayahNo, textWithEndSpan: withEnd));
      }

      surahs.add(
        QuranSurah(
          number: number,
          nameAr: nameAr,
          displayNameEn: displayNameEn,
          revelationLabel: revelationLabel,
          ayahCount: ayahs.length,
          ayahs: ayahs,
        ),
      );
    }

    return QuranArabicOnlyBundle(surahs: surahs);
  }

  static String _normalizeSurahName(String s, int number) {
    final t = s.trim();
    if (t.isEmpty || t.toLowerCase().startsWith('surah')) {
      return _fallbackEn[number] ?? 'Surah $number';
    }
    return t;
  }

  static String _toArabicIndicDigits(int n) {
    const map = {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    };
    return n.toString().split('').map((c) => map[c] ?? c).join();
  }

  static const Map<int, String> _fallbackEn = {
    1: 'Al-Fatihah',
    2: 'Al-Baqarah',
    3: "Ali 'Imran",
    4: "An-Nisa'",
    5: "Al-Ma'idah",
    6: "Al-An'am",
    7: "Al-A'raf",
    8: "Al-Anfal",
    9: "At-Taubah",
    10: "Yunus",
    11: "Hud",
    12: "Yusuf",
    13: "Ar-Ra'd",
    14: "Ibrahim",
    15: "Al-Hijr",
    16: "An-Nahl",
    17: "Al-Isra'",
    18: "Al-Kahf",
    19: "Maryam",
    20: "Taha",
    21: "Al-Anbiya'",
    22: "Al-Hajj",
    23: "Al-Mu'minun",
    24: "An-Nur",
    25: "Al-Furqan",
    26: "Ash-Shu'ara'",
    27: "An-Naml",
    28: "Al-Qasas",
    29: "Al-'Ankabut",
    30: "Ar-Rum",
    31: "Luqman",
    32: "As-Sajdah",
    33: "Al-Ahzab",
    34: "Saba'",
    35: "Fatir",
    36: "Ya-Sin",
    37: "As-Saffat",
    38: "Sad",
    39: "Az-Zumar",
    40: "Ghafir",
    41: "Fussilat",
    42: "Ash-Shura",
    43: "Az-Zukhruf",
    44: "Ad-Dukhan",
    45: "Al-Jathiyah",
    46: "Al-Ahqaf",
    47: "Muhammad",
    48: "Al-Fath",
    49: "Al-Hujurat",
    50: "Qaf",
    51: "Adh-Dhariyat",
    52: "At-Tur",
    53: "An-Najm",
    54: "Al-Qamar",
    55: "Ar-Rahman",
    56: "Al-Waqi'ah",
    57: "Al-Hadid",
    58: "Al-Mujadilah",
    59: "Al-Hashr",
    60: "Al-Mumtahanah",
    61: "As-Saff",
    62: "Al-Jumu'ah",
    63: "Al-Munafiqun",
    64: "At-Taghabun",
    65: "At-Talaq",
    66: "At-Tahrim",
    67: "Al-Mulk",
    68: "Al-Qalam",
    69: "Al-Haqqah",
    70: "Al-Ma'arij",
    71: "Nuh",
    72: "Al-Jinn",
    73: "Al-Muzzammil",
    74: "Al-Muddaththir",
    75: "Al-Qiyamah",
    76: "Al-Insan",
    77: "Al-Mursalat",
    78: "An-Naba'",
    79: "An-Nazi'at",
    80: "'Abasa",
    81: "At-Takwir",
    82: "Al-Infitar",
    83: "Al-Mutaffifin",
    84: "Al-Inshiqaq",
    85: "Al-Buruj",
    86: "At-Tariq",
    87: "Al-A'la",
    88: "Al-Ghashiyah",
    89: "Al-Fajr",
    90: "Al-Balad",
    91: "Ash-Shams",
    92: "Al-Lail",
    93: "Ad-Duha",
    94: "Ash-Sharh",
    95: "At-Tin",
    96: "Al-'Alaq",
    97: "Al-Qadr",
    98: "Al-Bayyinah",
    99: "Az-Zalzalah",
    100: "Al-'Adiyat",
    101: "Al-Qari'ah",
    102: "At-Takathur",
    103: "Al-'Asr",
    104: "Al-Humazah",
    105: "Al-Fil",
    106: "Quraish",
    107: "Al-Ma'un",
    108: "Al-Kauthar",
    109: "Al-Kafirun",
    110: "An-Nasr",
    111: "Al-Masad",
    112: "Al-Ikhlas",
    113: "Al-Falaq",
    114: "An-Nas",
  };
}

// =====================================================
// Sanitizer
// =====================================================

class QuranTextSanitizer {
  static String removeBadCircleMarks(String input) {
    final b = StringBuffer();
    for (final r in input.runes) {
      if (r == 0x06DD) continue;
      if (r == 0x0672) continue; // Alef Wavy Hamza — renders as circle in KFGQPC
      final isQuranMark = (r >= 0x06D6 && r <= 0x06ED);
      final keep = (r == 0x06DE) || (r == 0x06E9);
      if (isQuranMark && !keep) continue;
      b.writeCharCode(r);
    }
    return b.toString();
  }
}

// =====================================================
// Juz index
// =====================================================

class JuzRow {
  final int juz;
  final int surah;
  final int ayah;
  const JuzRow(this.juz, this.surah, this.ayah);
}

class JuzIndex {
  static const List<JuzRow> rows = [
    JuzRow(1, 1, 1),
    JuzRow(2, 2, 142),
    JuzRow(3, 2, 253),
    JuzRow(4, 3, 93),
    JuzRow(5, 4, 24),
    JuzRow(6, 4, 148),
    JuzRow(7, 5, 82),
    JuzRow(8, 6, 111),
    JuzRow(9, 7, 88),
    JuzRow(10, 8, 41),
    JuzRow(11, 9, 93),
    JuzRow(12, 11, 6),
    JuzRow(13, 12, 53),
    JuzRow(14, 15, 1),
    JuzRow(15, 17, 1),
    JuzRow(16, 18, 75),
    JuzRow(17, 21, 1),
    JuzRow(18, 23, 1),
    JuzRow(19, 25, 21),
    JuzRow(20, 27, 56),
    JuzRow(21, 29, 46),
    JuzRow(22, 33, 31),
    JuzRow(23, 36, 28),
    JuzRow(24, 39, 32),
    JuzRow(25, 41, 47),
    JuzRow(26, 46, 1),
    JuzRow(27, 51, 31),
    JuzRow(28, 58, 1),
    JuzRow(29, 67, 1),
    JuzRow(30, 78, 1),
  ];
}
// =====================================================
// Date format helper
// =====================================================

class _DateFmt {
  static String two(int n) => n < 10 ? '0$n' : '$n';

  static String format(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = two(d.day);
    final mon = two(d.month);
    final yr = d.year.toString();
    final hh = two(d.hour);
    final mm = two(d.minute);
    return '$day/$mon/$yr • $hh:$mm';
  }
}

// =====================================================
// Tajweed store
// =====================================================

class TajweedStore {
  final Map<String, String> _map;

  TajweedStore._(this._map);

  static Future<TajweedStore> load({required String path}) async {
    final raw = await rootBundle.loadString(path);
    final decoded = json.decode(raw);

    final out = <String, String>{};

    if (decoded is Map<String, dynamic>) {
      for (final surahEntry in decoded.entries) {
        final surahNo = int.tryParse(surahEntry.key);
        final verses = surahEntry.value;

        if (surahNo == null || verses is! List) continue;

        for (final item in verses) {
          if (item is! Map) continue;

          final m = Map<String, dynamic>.from(item);
          final ayahNo = m['ayah'];
          final text = m['arabic_tajweed'];

          if (ayahNo == null || text == null) continue;

          out['$surahNo:$ayahNo'] = text.toString();
        }
      }
    }

    return TajweedStore._(out);
  }

  String? textFor({
    required int surahNumber,
    required int ayahNumber,
  }) {
    return _map['$surahNumber:$ayahNumber'];
  }
}

// =====================================================
// App bundle
// =====================================================

class _AppBundle {
  final QuranArabicOnlyBundle quran;
  final LocalTranslationStore translations;
  final TajweedStore tajweed;

  _AppBundle({
    required this.quran,
    required this.translations,
    required this.tajweed,
  });
}
