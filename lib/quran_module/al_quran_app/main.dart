import '../../../services/prefs_service.dart';
// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;

import 'tajwid/tajwid_rich_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../theme/app_theme.dart';

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
          primary: const Color(0xFF8FE6B5),      // light green (more visible)
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

    final q = await QuranLoader.loadArabicOnly(uthmaniXmlPath: kUthmaniXmlPath);

    final t = await LocalTranslationStore.loadWithQuran(
      quran: q,
      msPath: 'assets/translations/ms.json',
      enPath: 'assets/translations/en.json',
    );

    debugPrint('✅ MS count: ${t.debugCountMs}, EN count: ${t.debugCountEn}');
    return _AppBundle(quran: q, translations: t);
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
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
                  onOpenSurah: (s) => _openSurahReader(context, bundle, s, startAyah: 1),
                ),
                JuzTab(
                  quran: bundle.quran,
                  primary: primary,
                  onOpen: (surahNo, ayahNo) {
                    final surah = bundle.quran.surahs.firstWhere((x) => x.number == surahNo);
                    _openSurahReader(context, bundle, surah, startAyah: ayahNo);
                  },
                ),
                BookmarkTab(
                  quran: bundle.quran,
                  store: _bookmarks,
                  primary: primary,
                  onOpen: (surahNo, ayahNo) {
                    final surah = bundle.quran.surahs.firstWhere((x) => x.number == surahNo);
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

  Future<void> _openSearch(BuildContext context, QuranArabicOnlyBundle quran) async {
    final result = await showModalBottomSheet<_JumpResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(quran: quran),
    );
    if (!mounted || result == null) return;

    final surah = quran.surahs.firstWhere((s) => s.number == result.surahNumber);
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

  const SurahTab({
    super.key,
    required this.quran,
    required this.primary,
    required this.arabicTitleFamily,
    required this.onOpenSurah,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      itemCount: quran.surahs.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 1.0)),
      itemBuilder: (context, i) {
        final s = quran.surahs[i];
        return InkWell(
          onTap: () => onOpenSurah(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OctaBadge(number: s.number, size: 44, stroke: primary.withOpacity(0.65)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.displayNameEn,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white.withOpacity(0.90) : Colors.black.withOpacity(0.88),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${s.revelationLabel} | ${s.ayahCount} AYAT',
                        style: TextStyle(
                          letterSpacing: 0.5,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primary.withOpacity(isDark ? 0.95 : 0.90),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  s.nameAr,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 34,
                    fontFamily: arabicTitleFamily,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.86),
                  ),
                ),
              ],
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
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 1.0)),
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
                OctaBadge(number: r.juz, size: 44, stroke: primary.withOpacity(0.65)),
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
                          color: isDark ? Colors.white.withOpacity(0.90) : Colors.black.withOpacity(0.88),
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
                Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black45),
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
            color: isDark ? Colors.white.withOpacity(0.75) : Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.45 : 1.0)),
      itemBuilder: (context, i) {
        final b = items[i];
        final surah = widget.quran.surahs.firstWhere((s) => s.number == b.surahNumber);
        final title = '${surah.displayNameEn} • Ayat ${b.ayahNumber}';
        final sub = _DateFmt.format(b.timestampMs);

        return ListTile(
          leading: OctaBadge(number: b.slot + 1, size: 42, stroke: widget.primary.withOpacity(0.65)),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white.withOpacity(0.90) : Colors.black.withOpacity(0.88),
            ),
          ),
          subtitle: Text(
            sub,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: widget.primary.withOpacity(isDark ? 0.95 : 0.90),
            ),
          ),
          trailing: IconButton(
            tooltip: 'Padam',
            icon: Icon(Icons.delete_outline, color: isDark ? Colors.white70 : Colors.black54),
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
// Surah Reader Page (FAST + ACCURATE JUMP)
// =====================================================

class SurahReaderPage extends StatefulWidget {
  final QuranSurah surah;
  final QuranArabicOnlyBundle quran;
  final LocalTranslationStore translations;
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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  int? _highlightAyah;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToAyah(widget.startAyah);
    });
  }

  void _jumpToAyah(int ayahNo) {
    final safeAyah = ayahNo.clamp(1, widget.surah.ayahs.length);
    final index = safeAyah - 1;

    setState(() => _highlightAyah = safeAyah);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightAyah == safeAyah) {
        setState(() => _highlightAyah = null);
      }
    });

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    }
  }

  // ✅ Realtime settings: sheet updates store directly
  Future<void> _openReaderSettings(BuildContext context, bool isDark) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReaderSettingsSheet(isDark: isDark, store: widget.settingsStore),
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
          appBar: AppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: Text('${widget.surah.number}. ${widget.surah.displayNameEn}'),
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
                    final s2 = widget.quran.surahs.firstWhere((x) => x.number == result.surahNumber);

                    if (!mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahReaderPage(
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
                tooltip: 'Tetapan Bacaan',
                icon: const Icon(Icons.tune),
                onPressed: () => _openReaderSettings(context, isDark),
              ),
            ],
          ),
          body: ScrollablePositionedList.separated(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: widget.surah.ayahs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final ayah = widget.surah.ayahs[i];
              final ayahNo = ayah.ayahNumber;
              final surahNo = widget.surah.number;

              final cleaned = QuranTextSanitizer.removeBadCircleMarks(ayah.textWithEndSpan);

              final isHighlighted = (_highlightAyah == ayahNo);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () async {
                  // ✅ Vibrate / haptic confirm
                  await HapticFeedback.heavyImpact(); // or lightImpact / selectionClick

                  await widget.bookmarks.addOrCycle(
                    surahNumber: surahNo,
                    ayahNumber: ayahNo,
                  );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark disimpan.')),
                  );
                },
                child: AyahCard(
                  isDark: isDark,
                  highlight: isHighlighted,
                  arabicMarkup: cleaned,
                  quranFontFamily: widget.quranFontFamily,
                  arabicFontSize: s.arabicFontSize,
                  arabicLineHeight: s.arabicLineHeight,
                  showTranslation: s.showTranslation,
                  translationLang: s.translationLang,
                  translationStore: widget.translations,
                  surahNumber: surahNo,
                  ayahNumber: ayahNo,
                  translationFontSize: s.translationFontSize,
                  translationLineHeight: s.translationLineHeight,
                ),
              );
            },
          ),
        );
      },
    );
  }
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
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    final cardColor = highlight
        ? primary.withOpacity(isDark ? 0.16 : 0.12)
        : (isDark ? Colors.white.withOpacity(0.06) : cs.surface);

    final borderColor = highlight
        ? primary.withOpacity(isDark ? 0.55 : 0.45)
        : (isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: highlight ? 1.6 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TajwidRichText(
            key: ValueKey(
              'ar_${surahNumber}_${ayahNumber}_${arabicFontSize.toStringAsFixed(1)}_${arabicLineHeight.toStringAsFixed(2)}',
            ),
            tajwidMarkup: arabicMarkup,
            fontFamily: quranFontFamily,
            fontSize: arabicFontSize,
            height: arabicLineHeight,
            textAlign: TextAlign.center,
            enableColors: false,
          ),
          if (showTranslation) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final t = translationStore
                    .translationFor(
                  surahNumber: surahNumber,
                  ayahNumber: ayahNumber,
                  lang: translationLang,
                )
                    .trim();

                if (t.isEmpty) return const SizedBox.shrink();
                return Text(
                  t,
                  key: ValueKey('tr_${surahNumber}_${ayahNumber}_${translationLang.name}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: translationFontSize,
                    height: translationLineHeight,
                    color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.80),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ],
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
    final name = widget.quran.surahs.firstWhere((x) => x.number == s).displayNameEn;
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
                border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cari / Lompat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.86),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _surahCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Surah (1–114)'),
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _surahNamePreview.isEmpty ? 'Masukkan nombor surah untuk lihat nama.' : _surahNamePreview,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white.withOpacity(0.88) : Colors.black.withOpacity(0.80),
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
      translationFontSize: (j['translationFontSize'] as num?)?.toDouble() ?? 16.0,
      translationLineHeight: (j['translationLineHeight'] as num?)?.toDouble() ?? 1.35,
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
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
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

                          _label(isDark, 'Saiz Arab: ${s.arabicFontSize.toStringAsFixed(0)}'),
                          _compactSlider(
                            context,
                            value: s.arabicFontSize,
                            min: 22,
                            max: 48,
                            divisions: 26,
                            onChanged: (v) => store.update((x) => x.arabicFontSize = v),
                          ),

                          _label(isDark, 'Line Arab: ${s.arabicLineHeight.toStringAsFixed(2)}'),
                          _compactSlider(
                            context,
                            value: s.arabicLineHeight,
                            min: 1.10,
                            max: 2.30,
                            divisions: 24,
                            onChanged: (v) => store.update((x) => x.arabicLineHeight = v),
                          ),

                          const SizedBox(height: 2),

                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -2), // ✅ tighter
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: s.showTranslation,
                            onChanged: (v) => store.update((x) => x.showTranslation = v),
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
                                  ButtonSegment(value: TranslationLang.ms, label: Text('BM')),
                                  ButtonSegment(value: TranslationLang.en, label: Text('EN')),
                                ],
                                selected: {s.translationLang},
                                onSelectionChanged: (set) =>
                                    store.update((x) => x.translationLang = set.first),
                              ),
                            ),

                            const SizedBox(height: 6),

                            _label(isDark, 'Saiz Terjemahan: ${s.translationFontSize.toStringAsFixed(0)}'),
                            _compactSlider(
                              context,
                              value: s.translationFontSize,
                              min: 12,
                              max: 24,
                              divisions: 12,
                              onChanged: (v) => store.update((x) => x.translationFontSize = v),
                            ),

                            _label(isDark, 'Line Terjemahan: ${s.translationLineHeight.toStringAsFixed(2)}'),
                            _compactSlider(
                              context,
                              value: s.translationLineHeight,
                              min: 1.10,
                              max: 1.80,
                              divisions: 14,
                              onChanged: (v) => store.update((x) => x.translationLineHeight = v),
                            ),
                          ],

                          const SizedBox(height: 6),

                          SizedBox(
                            height: 40, // ✅ smaller button
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
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
          color: isDark ? Colors.white.withOpacity(0.82) : Colors.black.withOpacity(0.72),
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
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), // ✅ smaller thumb
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
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
  bool shouldRepaint(covariant _StarPainter oldDelegate) => oldDelegate.stroke != stroke;
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
      timestampMs: (j['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class BookmarkStore {
  static const _prefsKey = 'bookmarks_v2';
  static const _max = 5;

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
            if (it is Map<String, dynamic>) items.add(BookmarkItem.fromJson(it));
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

  Future<void> addOrCycle({required int surahNumber, required int ayahNumber}) async {
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

  static Map<String, String> _mapFromSequentialList(QuranArabicOnlyBundle quran, List list, String label) {
    final out = <String, String>{};

    final strings = <String>[];
    for (final x in list) {
      if (x is String) strings.add(x);
      else if (x is num) strings.add(x.toString());
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

    debugPrint('✅ [$label] sequential list mapped => ${out.length} entries (input=${strings.length})');
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
        final sample = decoded.take(decoded.length < 20 ? decoded.length : 20).toList();
        final stringCount = sample.whereType<String>().length;
        final isMostlyString = sample.isNotEmpty && (stringCount / sample.length) >= 0.6;
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
            return s.contains(':') || s.contains('|') || s.contains('_') || s.contains('-');
          });

          if (looksLikeVerseKeyMap) {
            for (final e in node.entries) {
              putKV(e.key.toString(), (e.value ?? '').toString());
            }
            return;
          }

          for (final key in const ['quran', 'data', 'result', 'translations', 'surahs', 'verses', 'items']) {
            if (node.containsKey(key)) {
              extract(node[key], currentSurah: currentSurah);
            }
          }

          final verseKey = (node['verse_key'] ?? node['verseKey'] ?? node['ayah_key'] ?? '').toString().trim();
          if (verseKey.isNotEmpty) {
            final text = (node['text'] ?? node['translation'] ?? node['translate'] ?? node['meaning'] ?? '').toString();
            putKV(verseKey, text);
            return;
          }

          final sVal = node['sura'] ?? node['surah'] ?? node['chapter'] ?? node['id'] ?? node['s'];
          final aVal = node['aya'] ?? node['ayah'] ?? node['verse'] ?? node['a'];
          final sn = int.tryParse('$sVal');
          final an = int.tryParse('$aVal');
          final t = (node['translation'] ?? node['text'] ?? node['translate'] ?? node['meaning'] ?? '').toString().trim();
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
    1, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 25, 26, 27, 28, 29, 30, 31, 32,
    34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 50, 51, 52, 53, 54, 55, 56, 57, 67, 68, 69,
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93,
    94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114,
  };

  static Future<QuranArabicOnlyBundle> loadArabicOnly({required String uthmaniXmlPath}) async {
    final xmlString = await rootBundle.loadString(uthmaniXmlPath);
    final doc = XmlDocument.parse(xmlString);

    final quran = doc.findAllElements('quran').first;
    final suraNodes = quran.findAllElements('sura').toList();
    if (suraNodes.isEmpty) throw Exception('No <sura> nodes found in $uthmaniXmlPath');

    final surahs = <QuranSurah>[];

    for (final s in suraNodes) {
      final number = int.tryParse(s.getAttribute('index') ?? '') ?? (surahs.length + 1);
      final nameAr = (s.getAttribute('name') ?? '').trim();

      final nameEnRaw = (s.getAttribute('tname') ?? 'Surah $number').trim();
      final displayNameEn = _normalizeSurahName(nameEnRaw, number);

      final isMakki = _makkiSet.contains(number);
      final revelationLabel = isMakki ? 'MEKAH' : 'MADINAH';

      final ayahs = <QuranAyah>[];
      for (final a in s.findAllElements('aya')) {
        final ayahNo = int.tryParse(a.getAttribute('index') ?? '') ?? (ayahs.length + 1);
        final rawText = (a.getAttribute('text') ?? '').trim();
        if (rawText.isEmpty) continue;

        final withEnd = '$rawText <span class=end>${_toArabicIndicDigits(ayahNo)}</span>';
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

class _AppBundle {
  final QuranArabicOnlyBundle quran;
  final LocalTranslationStore translations;

  _AppBundle({required this.quran, required this.translations});
}