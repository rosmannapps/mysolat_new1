import '../services/prefs_service.dart';
// lib/pages/quran_reader_page.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../services/bookmark_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/aa_text_settings_sheet.dart';

// Must match pubspec.yaml
const String kQuranFontFamily = 'KFGQPC';

class QuranAyah {
  final int numberInSurah;
  final String arabic;
  final String? translationMs;

  QuranAyah({
    required this.numberInSurah,
    required this.arabic,
    this.translationMs,
  });
}

class QuranReaderPage extends StatefulWidget {
  final int surahNumber;
  final String surahLatin;
  final String surahArabic;
  final int ayahCount;
  final int? initialAyah;

  const QuranReaderPage({
    super.key,
    required this.surahNumber,
    required this.surahLatin,
    required this.surahArabic,
    required this.ayahCount,
    this.initialAyah,
  });

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  late Future<List<QuranAyah>> _futureAyat;

  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _didInitialScroll = false;

  // Translation
  bool _showTranslation = true;

  // Single source of truth for UI numbers and real sizes
  int _arabicValue = 26;
  int _malayValue = 14;

  // Limits
  static const int _aMin = 20;
  static const int _aMax = 44;
  static const int _mMin = 12;
  static const int _mMax = 28;

  double get _arabicSize => _arabicValue.toDouble();
  double get _malaySize => _malayValue.toDouble();

  // Floating "Aa" button
  Offset _aaOffset = const Offset(300, 520);

  // Floating panel
  bool _showAaPanel = false;
  Offset _panelOffset = const Offset(24, 420);

  // Glass tuning (transparent)
  static const double _glassOpacity = 0.055;

  // Pref keys
  String get _prefs => 'quran_reader_theme_v1';
  String get _kArabic => '$_prefs.arabic';
  String get _kMalay => '$_prefs.malay';
  String get _kShowTrans => '$_prefs.trans';
  String get _kAaDx => '$_prefs.aa_dx';
  String get _kAaDy => '$_prefs.aa_dy';
  String get _kPanelDx => '$_prefs.panel_dx';
  String get _kPanelDy => '$_prefs.panel_dy';

  @override
  void initState() {
    super.initState();
    _futureAyat = _loadSurah(widget.surahNumber);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = PrefsService.instance;
    if (!mounted) return;

    setState(() {
      _arabicValue = (p.getInt(_kArabic) ?? 26).clamp(_aMin, _aMax);
      _malayValue = (p.getInt(_kMalay) ?? 14).clamp(_mMin, _mMax);
      _showTranslation = p.getBool(_kShowTrans) ?? true;

      final dx = p.getDouble(_kAaDx);
      final dy = p.getDouble(_kAaDy);
      if (dx != null && dy != null) _aaOffset = Offset(dx, dy);

      final pdx = p.getDouble(_kPanelDx);
      final pdy = p.getDouble(_kPanelDy);
      if (pdx != null && pdy != null) _panelOffset = Offset(pdx, pdy);
    });
  }

  Future<void> _savePrefs() async {
    final p = PrefsService.instance;
    await p.setInt(_kArabic, _arabicValue);
    await p.setInt(_kMalay, _malayValue);
    await p.setBool(_kShowTrans, _showTranslation);
    await p.setDouble(_kAaDx, _aaOffset.dx);
    await p.setDouble(_kAaDy, _aaOffset.dy);
    await p.setDouble(_kPanelDx, _panelOffset.dx);
    await p.setDouble(_kPanelDy, _panelOffset.dy);
  }

  // ---------------------------------------------------------------------------
  // LOAD SURAH
  // ---------------------------------------------------------------------------

  Future<List<QuranAyah>> _loadSurah(int surahNumber) async {
    final padded = surahNumber.toString().padLeft(3, '0');
    final raw = await rootBundle.loadString('assets/quran/surahs/surah_$padded.json');
    final decoded = jsonDecode(raw);

    final List list = decoded is List ? decoded : (decoded['ayahs'] ?? []);
    final result = <QuranAyah>[];

    int fallback = 1;

    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final arabic = (m['arabic'] ?? m['textUthmani'] ?? m['text'] ?? '').toString().trim();
      if (arabic.isEmpty) continue;

      final dynNo = (m['numberInSurah'] ?? m['ayahNumber'] ?? m['number'] ?? fallback);
      final no = dynNo is int ? dynNo : int.tryParse(dynNo.toString()) ?? fallback;

      final trans = (m['ms'] ?? m['translationMs'] ?? m['translation'] ?? m['malay'])?.toString();

      result.add(
        QuranAyah(
          numberInSurah: no,
          arabic: arabic,
          translationMs: (trans?.trim().isNotEmpty ?? false) ? trans : null,
        ),
      );

      fallback++;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // FLOATING "Aa" BUTTON + PANEL
  // ---------------------------------------------------------------------------

  void _togglePanel() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _showAaPanel = !_showAaPanel;
      if (_showAaPanel) {
        _panelOffset = _clampPanelToScreen(
          Offset(_aaOffset.dx - 260, _aaOffset.dy - 20),
          size,
        );
      }
    });
    _savePrefs();
  }

  Offset _clampAaToScreen(Offset o, Size size) {
    const margin = 10.0;
    const w = 54.0;
    const h = 54.0;
    final dx = o.dx.clamp(margin, size.width - w - margin);
    final dy = o.dy.clamp(margin, size.height - h - margin);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  Offset _clampPanelToScreen(Offset o, Size size) {
    const margin = 10.0;
    const w = 320.0;
    const h = 220.0;
    final dx = o.dx.clamp(margin, size.width - w - margin);
    final dy = o.dy.clamp(margin, size.height - h - margin);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  void _snapAaToEdge() {
    final size = MediaQuery.of(context).size;
    const margin = 10.0;
    const w = 54.0;

    final bool snapRight = _aaOffset.dx > size.width / 2;
    final targetX = snapRight ? (size.width - w - margin) : margin;

    setState(() {
      _aaOffset = Offset(targetX, _aaOffset.dy);
      _aaOffset = _clampAaToScreen(_aaOffset, size);
    });
    _savePrefs();
  }

  void _haptic() => HapticFeedback.selectionClick();

  Widget _aaCircle(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'Aa',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _floatingAaButton(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final clamped = _clampAaToScreen(_aaOffset, size);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onTap: _togglePanel,
        onPanUpdate: (d) => setState(() => _aaOffset = _aaOffset + d.delta),
        onPanEnd: (_) => _snapAaToEdge(),
        child: _aaCircle(context),
      ),
    );
  }

  Widget _floatingPanel(BuildContext context) {
    if (!_showAaPanel) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final clamped = _clampPanelToScreen(_panelOffset, size);

    final isDark = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    // More readable in dark mode
    final panelBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(_glassOpacity);

    final panelBorder = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.18);

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _panelOffset = _panelOffset + d.delta),
        onPanEnd: (_) => _savePrefs(),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.22 : 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: AaTextSettingsSheet(
                  arabicValue: _arabicValue,
                  malayValue: _malayValue,
                  onArabicMinus: () {
                    _haptic();
                    setState(() => _arabicValue = (_arabicValue - 1).clamp(_aMin, _aMax));
                    _savePrefs();
                  },
                  onArabicPlus: () {
                    _haptic();
                    setState(() => _arabicValue = (_arabicValue + 1).clamp(_aMin, _aMax));
                    _savePrefs();
                  },
                  onMalayMinus: () {
                    _haptic();
                    setState(() => _malayValue = (_malayValue - 1).clamp(_mMin, _mMax));
                    _savePrefs();
                  },
                  onMalayPlus: () {
                    _haptic();
                    setState(() => _malayValue = (_malayValue + 1).clamp(_mMin, _mMax));
                    _savePrefs();
                  },
                  showTranslationToggle: true,
                  showTranslation: _showTranslation,
                  onToggleTranslation: (v) {
                    _haptic();
                    setState(() => _showTranslation = v);
                    _savePrefs();
                  },
                  // Inner sheet almost invisible (outer container is the glass)
                  backgroundOpacity: isDark ? 0.06 : 0.02,
                  margin: EdgeInsets.zero,
                  useSafeArea: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _circleIconButton(BuildContext context, {required Widget child, required VoidCallback onTap}) {
    final isDark = AppTheme.isDark(context);
    final bg = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82);
    final iconColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: IconTheme.merge(
          data: IconThemeData(color: iconColor),
          child: child,
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleColor = cs.onSurface;
    final subtitleColor = cs.onSurface.withOpacity(0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        children: [
          _circleIconButton(
            context,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.surahLatin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.surahArabic} • ${widget.ayahCount} ayat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKMARK
  // ---------------------------------------------------------------------------

  Future<void> _bookmarkAyah(QuranAyah ayah) async {
    final bookmark = Bookmark(
      surahNumber: widget.surahNumber,
      surahLatin: widget.surahLatin,
      surahArabic: widget.surahArabic,
      ayahNumber: ayah.numberInSurah,
    );

    await BookmarkStorage.addOrUpdate(bookmark);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Penanda disimpan: ${widget.surahLatin} ayat ${ayah.numberInSurah}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onAyahLongPress(QuranAyah ayah) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Penanda'),
          content: Text('Tandakan ${widget.surahLatin} • ayat ${ayah.numberInSurah} sebagai penanda?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _bookmarkAyah(ayah);
              },
              child: Text(
                'Simpan',
                style: TextStyle(color: AppTheme.primaryOf(context), fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bgOf(context);
    final cs = Theme.of(context).colorScheme;

    // Use theme colors (dark mode friendly)
    final arabicColor = cs.onSurface; // readable in both
    final translationColor = cs.onSurface.withOpacity(AppTheme.isDark(context) ? 0.82 : 0.90);

    // Ayah number chip (subtle, brand-consistent)
    final chipBg = AppTheme.isDark(context)
        ? Colors.white.withOpacity(0.08)
        : AppTheme.primarySoft;
    final chipText = AppTheme.isDark(context) ? cs.onSurface : AppTheme.primary;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: FutureBuilder<List<QuranAyah>>(
                    future: _futureAyat,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Ralat memuatkan surah:\n${snap.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurface),
                            ),
                          ),
                        );
                      }

                      final ayat = snap.data ?? <QuranAyah>[];
                      if (ayat.isEmpty) {
                        return Center(
                          child: Text(
                            'Tiada ayat dijumpai dalam fail JSON.',
                            style: TextStyle(color: cs.onSurface),
                          ),
                        );
                      }

                      if (!_didInitialScroll && widget.initialAyah != null) {
                        _didInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_itemScrollController.isAttached) {
                            final idx = (widget.initialAyah! - 1).clamp(0, ayat.length - 1);
                            _itemScrollController.scrollTo(
                              index: idx,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }

                      return ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemCount: ayat.length,
                        itemBuilder: (context, index) {
                          final a = ayat[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => _onAyahLongPress(a),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: 10,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          a.arabic,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            fontFamily: kQuranFontFamily,
                                            fontSize: _arabicSize,
                                            height: 2.05,
                                            color: arabicColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: chipBg,
                                            border: Border.all(
                                              color: AppTheme.isDark(context)
                                                  ? Colors.white.withOpacity(0.10)
                                                  : Colors.black.withOpacity(0.06),
                                            ),
                                          ),
                                          child: Text(
                                            a.numberInSurah.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: chipText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_showTranslation && (a.translationMs?.trim().isNotEmpty ?? false)) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      a.translationMs!,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: _malaySize,
                                        height: 1.75,
                                        color: translationColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Tap outside closes panel
          if (_showAaPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showAaPanel = false),
                child: const SizedBox.shrink(),
              ),
            ),

          _floatingAaButton(context),
          _floatingPanel(context),
        ],
      ),
    );
  }
}