// lib/pages/quran_reader_page.dart
//
// Quran.com–inspired reader for MySolat.
//
// Design highlights:
//   • Clean divider-based verse layout (no card borders)
//   • Ornate circular verse-number badge with Arabic-Indic numerals
//   • Beautiful surah header with Bismillah
//   • Persistent bottom audio bar with seek slider + verse indicator
//   • Tajweed-coloured Arabic text (KFGQPC font)
//   • Full audio: per-verse highlight, auto-scroll, download
//   • Collapsible tajweed colour legend
//   • Floating Aa settings panel

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../services/quran_audio_service.dart';
import '../services/bookmark_storage.dart';
import '../services/prefs_service.dart';
import '../tajweed_text.dart';
import '../theme/app_theme.dart';
import '../widgets/aa_text_settings_sheet.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const String kQuranFontFamily = 'KFGQPC';

// Converts 0–9 digits to Arabic-Indic numerals ٠١٢٣٤٥٦٧٨٩
String _toArabicNumerals(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

// ─── Data model ──────────────────────────────────────────────────────────────

class QuranAyah {
  final int numberInSurah;

  /// May contain tajweed HTML markup:  <tajweed class="ham_wasl">ٱ</tajweed>
  final String arabic;

  final String? translationMs;

  QuranAyah({
    required this.numberInSurah,
    required this.arabic,
    this.translationMs,
  });
}

// ─── Ornate verse-number badge ────────────────────────────────────────────────

class _OrnateBadgePainter extends CustomPainter {
  final Color primary;
  final bool  isPlaying;

  _OrnateBadgePainter({required this.primary, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // ── outer decorative ring ────────────────────────────────────────────────
    final outerPaint = Paint()
      ..color  = primary.withOpacity(isPlaying ? 0.9 : 0.55)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(cx, cy), r - 1, outerPaint);

    // ── 8 small diamond ornaments around the ring ────────────────────────────
    final diamondPaint = Paint()
      ..color = primary.withOpacity(isPlaying ? 1.0 : 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final dx    = cx + (r - 2.5) * math.cos(angle);
      final dy    = cy + (r - 2.5) * math.sin(angle);
      const half  = 2.2;

      final path = Path()
        ..moveTo(dx,          dy - half)
        ..lineTo(dx + half,   dy)
        ..lineTo(dx,          dy + half)
        ..lineTo(dx - half,   dy)
        ..close();

      canvas.drawPath(path, diamondPaint);
    }

    // ── inner filled circle ──────────────────────────────────────────────────
    final innerPaint = Paint()
      ..color = isPlaying
          ? primary
          : primary.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), r - 7, innerPaint);

    // inner border
    final innerBorder = Paint()
      ..color = primary.withOpacity(isPlaying ? 0.0 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(cx, cy), r - 7, innerBorder);
  }

  @override
  bool shouldRepaint(_OrnateBadgePainter old) =>
      old.primary != primary || old.isPlaying != isPlaying;
}

// ─── Tajweed colour legend rows ───────────────────────────────────────────────

class _TajweedLegendRow extends StatelessWidget {
  final Color  color;
  final String label;

  const _TajweedLegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.78),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main page widget ─────────────────────────────────────────────────────────

class QuranReaderPage extends StatefulWidget {
  final int    surahNumber;
  final String surahLatin;
  final String surahArabic;
  final int    ayahCount;
  final int?   initialAyah;

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

  // ── Tajweed JSON cache ─────────────────────────────────────────────────────
  static Map<String, dynamic>? _tajweedJsonCache;

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final ItemScrollController    _itemScrollController   = ItemScrollController();
  final ItemPositionsListener   _itemPositionsListener  = ItemPositionsListener.create();
  bool _didInitialScroll = false;

  // ── Settings ───────────────────────────────────────────────────────────────
  bool   _showTranslation  = true;
  bool   _showTajweedLegend = false;
  int    _arabicValue      = 28;
  int    _malayValue       = 15;

  static const int _aMin = 20, _aMax = 44;
  static const int _mMin = 12, _mMax = 28;

  double get _arabicSize => _arabicValue.toDouble();
  double get _malaySize  => _malayValue.toDouble();

  // ── Floating Aa panel ──────────────────────────────────────────────────────
  Offset _aaOffset    = const Offset(300, 520);
  bool   _showAaPanel = false;
  Offset _panelOffset = const Offset(24, 420);

  static const double _glassOpacity = 0.055;

  // ── Prefs keys ─────────────────────────────────────────────────────────────
  String get _pKey      => 'quran_reader_theme_v1';
  String get _kArabic   => '$_pKey.arabic';
  String get _kMalay    => '$_pKey.malay';
  String get _kShowTrans => '$_pKey.trans';
  String get _kAaDx     => '$_pKey.aa_dx';
  String get _kAaDy     => '$_pKey.aa_dy';
  String get _kPanelDx  => '$_pKey.panel_dx';
  String get _kPanelDy  => '$_pKey.panel_dy';

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _player           = AudioPlayer();
  List<QuranAyah>  _ayat             = [];
  List<AyahTiming> _timings          = [];
  int              _currentPlayIndex = -1;
  bool             _isPlaying        = false;
  bool             _isLoading        = false;
  double           _downloadProgress = 0.0;
  Duration         _position         = Duration.zero;
  Duration         _duration         = Duration.zero;

  // ─────────────────────────────────────────────────────────────────────────
  // Audio helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startPlayback({int startAyah = 1}) async {
    if (_ayat.isEmpty) return;
    setState(() { _isLoading = true; _downloadProgress = 0.0; });

    try {
      final surahAudio = await QuranAudioService.instance.prepare(
        widget.surahNumber,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );

      _timings = surahAudio.timings;

      Duration startPos = Duration.zero;
      if (startAyah > 1 && _timings.isNotEmpty) {
        final t = _timings.firstWhere(
              (t) => t.ayahNumber == startAyah,
          orElse: () => _timings.first,
        );
        startPos = Duration(milliseconds: t.startMs);
      }

      await _player.setFilePath(surahAudio.localPath);
      if (startPos > Duration.zero) await _player.seek(startPos);
      await _player.play();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[QuranAudio] $e');
      if (mounted) {
        setState(() { _isLoading = false; _downloadProgress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuatkan audio: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else if (_timings.isNotEmpty) {
      _player.play();
    } else {
      _startPlayback();
    }
  }

  void _stopPlayback() {
    _player.stop();
    setState(() {
      _isPlaying        = false;
      _isLoading        = false;
      _currentPlayIndex = -1;
      _downloadProgress = 0;
      _position         = Duration.zero;
    });
  }

  void _playAyah(int index) {
    if (_timings.isEmpty) {
      _startPlayback(startAyah: _ayat[index].numberInSurah);
      return;
    }
    final t = _timings.firstWhere(
          (t) => t.ayahNumber == _ayat[index].numberInSurah,
      orElse: () => _timings[index.clamp(0, _timings.length - 1)],
    );
    _player.seek(Duration(milliseconds: t.startMs));
    if (!_isPlaying) _player.play();
  }

  void _previousAyah() {
    final idx = (_currentPlayIndex - 1).clamp(0, _ayat.length - 1);
    _playAyah(idx);
  }

  void _nextAyah() {
    final idx = (_currentPlayIndex + 1).clamp(0, _ayat.length - 1);
    _playAyah(idx);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _futureAyat = _loadSurah(widget.surahNumber);
    _loadPrefs();

    // Position → ayah highlight + auto-scroll
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      if (_timings.isEmpty) return;
      final ms    = pos.inMilliseconds;
      final index = QuranAudioService.instance.ayahIndexAt(_timings, ms);
      if (index >= 0 && index != _currentPlayIndex) {
        setState(() => _currentPlayIndex = index);
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index:    index + 1, // +1 because item 0 is the surah header
            duration: const Duration(milliseconds: 400),
            curve:    Curves.easeInOut,
          );
        }
      }
    });

    // Duration
    _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });

    // Mirror playing state
    _player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    });

    // Reset when complete
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying        = false;
          _isLoading        = false;
          _currentPlayIndex = -1;
          _position         = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Prefs
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final p = PrefsService.instance;
    if (!mounted) return;
    setState(() {
      _arabicValue     = (p.getInt(_kArabic)  ?? 28).clamp(_aMin, _aMax);
      _malayValue      = (p.getInt(_kMalay)   ?? 15).clamp(_mMin, _mMax);
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
    await p.setInt(_kArabic,      _arabicValue);
    await p.setInt(_kMalay,       _malayValue);
    await p.setBool(_kShowTrans,  _showTranslation);
    await p.setDouble(_kAaDx,     _aaOffset.dx);
    await p.setDouble(_kAaDy,     _aaOffset.dy);
    await p.setDouble(_kPanelDx,  _panelOffset.dx);
    await p.setDouble(_kPanelDy,  _panelOffset.dy);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Surah loader
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<QuranAyah>> _loadSurah(int surahNumber) async {
    _tajweedJsonCache ??= jsonDecode(
      await rootBundle.loadString('assets/tajwid/quran_tajweed.json'),
    ) as Map<String, dynamic>;

    final surahList = (_tajweedJsonCache!['$surahNumber'] as List?) ?? [];

    final tajweedMap = <int, String>{};
    for (final item in surahList) {
      if (item is! Map) continue;
      final rawNo = item['ayah'];
      final text  = item['arabic_tajweed'];
      if (rawNo == null || text == null) continue;
      final no = rawNo is int ? rawNo : int.tryParse('$rawNo') ?? 0;
      if (no > 0) tajweedMap[no] = '$text';
    }

    final padded = surahNumber.toString().padLeft(3, '0');
    final raw    = await rootBundle.loadString('assets/quran/surahs/surah_$padded.json');
    final decoded = jsonDecode(raw);
    final List list = decoded is List ? decoded : (decoded['ayahs'] ?? []);

    final result  = <QuranAyah>[];
    int   fallback = 1;

    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final dynNo = m['numberInSurah'] ?? m['ayahNumber'] ?? m['number'] ?? m['ayah'] ?? fallback;
      final no    = dynNo is int ? dynNo : int.tryParse(dynNo.toString()) ?? fallback;

      final arabic = tajweedMap[no] ??
          (m['arabic_tajweed'] ?? m['arabic'] ?? m['textUthmani'] ?? m['text'] ?? '')
              .toString()
              .trim();
      if (arabic.isEmpty) continue;

      final trans = (m['ms'] ?? m['translationMs'] ?? m['translation'] ?? m['malay'])
          ?.toString();

      result.add(QuranAyah(
        numberInSurah: no,
        arabic:        arabic,
        translationMs: (trans?.trim().isNotEmpty ?? false) ? trans : null,
      ));

      fallback++;
    }

    _ayat = result;
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Ayah actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _bookmarkAyah(QuranAyah ayah) async {
    await BookmarkStorage.addOrUpdate(Bookmark(
      surahNumber: widget.surahNumber,
      surahLatin:  widget.surahLatin,
      surahArabic: widget.surahArabic,
      ayahNumber:  ayah.numberInSurah,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Penanda disimpan • ${widget.surahLatin} ${ayah.numberInSurah}'),
    ));
  }

  Future<void> _copyAyah(QuranAyah ayah) async {
    await Clipboard.setData(ClipboardData(
      text: '${ayah.arabic}\n\n${ayah.translationMs ?? ''}\n\n'
          '(${widget.surahLatin} ${ayah.numberInSurah})',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayat disalin')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Download helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showDownloadOptions() {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

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
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Muat Turun Audio',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.surahLatin,
              style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            _downloadTile(
              context,
              icon:        Icons.music_note_rounded,
              title:       'Muat Turun Surah Penuh',
              subtitle:    'Satu fail audio berterusan — tilawah lancar tanpa henti.',
              recommended: true,
              onTap: () { Navigator.pop(context); _startPlayback(); },
            ),
            const SizedBox(height: 12),
            _downloadTile(
              context,
              icon:        Icons.format_list_numbered_rounded,
              title:       'Muat Turun Per Ayat',
              subtitle:    'Setiap ayat disimpan berasingan — sesuai untuk hafazan.',
              recommended: false,
              onTap: () { Navigator.pop(context); _downloadPerAyah(); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadTile(
      BuildContext context, {
        required IconData   icon,
        required String     title,
        required String     subtitle,
        required bool       recommended,
        required VoidCallback onTap,
      }) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: recommended
              ? primary.withOpacity(isDark ? 0.15 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: recommended
                ? primary.withOpacity(0.35)
                : cs.onSurface.withOpacity(0.08),
            width: recommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: recommended
                    ? primary.withOpacity(0.15)
                    : cs.onSurface.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: recommended ? primary : cs.onSurface, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary, borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text('Disyor',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.55), height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPerAyah() async {
    if (_ayat.isEmpty) return;
    final total = _ayat.length;
    setState(() { _isLoading = true; _downloadProgress = 0; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Memuat turun $total ayat untuk ${widget.surahLatin}…'),
      duration: const Duration(seconds: 2),
    ));
    try {
      await QuranAudioService.instance.downloadPerAyah(
        surahNumber: widget.surahNumber,
        ayahCount:   total,
        onProgress:  (i) {
          if (mounted) setState(() => _downloadProgress = i / total);
        },
      );
      if (mounted) {
        setState(() { _isLoading = false; _downloadProgress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ $total ayat ${widget.surahLatin} berjaya dimuat turun.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _downloadProgress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Floating Aa helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _togglePanel() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _showAaPanel = !_showAaPanel;
      if (_showAaPanel) {
        _panelOffset = _clampPanel(Offset(_aaOffset.dx - 260, _aaOffset.dy - 20), size);
      }
    });
    _savePrefs();
  }

  Offset _clampAa(Offset o, Size size) {
    const m = 10.0; const w = 54.0; const h = 54.0;
    return Offset(
      o.dx.clamp(m, size.width  - w - m).toDouble(),
      o.dy.clamp(m, size.height - h - m).toDouble(),
    );
  }

  Offset _clampPanel(Offset o, Size size) {
    const m = 10.0; const w = 320.0; const h = 230.0;
    return Offset(
      o.dx.clamp(m, size.width  - w - m).toDouble(),
      o.dy.clamp(m, size.height - h - m).toDouble(),
    );
  }

  void _snapAa() {
    final size = MediaQuery.of(context).size;
    const margin = 10.0; const w = 54.0;
    final right  = _aaOffset.dx > size.width / 2;
    setState(() {
      _aaOffset = _clampAa(
        Offset(right ? size.width - w - margin : margin, _aaOffset.dy),
        size,
      );
    });
    _savePrefs();
  }

  void _haptic() => HapticFeedback.selectionClick();

  // ─────────────────────────────────────────────────────────────────────────
  // Sub-widgets
  // ─────────────────────────────────────────────────────────────────────────

  // ── App bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          // Back
          _iconCircle(
            context,
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: cs.onSurface),
            onTap: () { _stopPlayback(); Navigator.of(context).maybePop(); },
          ),
          const SizedBox(width: 8),

          // Surah name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.surahNumber}. ${widget.surahLatin}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: cs.onSurface, height: 1.2,
                  ),
                ),
                Text(
                  '${widget.surahArabic}  •  ${widget.ayahCount} ayat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Tajweed legend toggle
          _iconCircle(
            context,
            child: Icon(Icons.palette_outlined, size: 20, color: primary),
            onTap: () => setState(() => _showTajweedLegend = !_showTajweedLegend),
          ),
          const SizedBox(width: 4),

          // Download
          _iconCircle(
            context,
            child: Icon(Icons.download_rounded, size: 20, color: primary),
            onTap: _showDownloadOptions,
          ),
        ],
      ),
    );
  }

  Widget _iconCircle(BuildContext context, {required Widget child, required VoidCallback onTap}) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // ── Tajweed colour legend ─────────────────────────────────────────────────

  Widget _buildTajweedLegend(BuildContext context) {
    if (!_showTajweedLegend) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);
    final cs     = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.onSurface.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Text(
                  'Warna Tajwid',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showTajweedLegend = false),
                  child: Icon(Icons.close, size: 16, color: cs.onSurface.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 4),
          // Two-column grid
          _legendGrid(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _legendGrid() {
    const items = [
      (Color(0xFF9AA0A6), 'Hamzah Wasl / Saktah'),
      (Color(0xFF537FFF), 'Madd Biasa 2 harakat'),
      (Color(0xFF4050FF), 'Madd Harus 2/4/6 harakat'),
      (Color(0xFF000EBC), 'Madd Wajib 4-5 harakat'),
      (Color(0xFF2144C1), 'Madd Lazim 6 harakat'),
      (Color(0xFFDD0008), 'Qalqalah'),
      (Color(0xFF9400A8), 'Ikhfa'),
      (Color(0xFFD500B7), 'Ikhfa Syafawi'),
      (Color(0xFF26BFFD), 'Iqlab'),
      (Color(0xFF169777), 'Idgham Ghunnah'),
      (Color(0xFF169200), 'Idgham Tanpa Ghunnah'),
      (Color(0xFF58B800), 'Idgham Syafawi'),
      (Color(0xFFFF7E1E), 'Ghunnah'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        children: items.map((e) => SizedBox(
          width: 210,
          child: _TajweedLegendRow(color: e.$1, label: e.$2),
        )).toList(),
      ),
    );
  }

  // ── Download progress bar ─────────────────────────────────────────────────

  Widget _buildDownloadBar(BuildContext context) {
    if (!_isLoading || _downloadProgress >= 1.0) return const SizedBox.shrink();

    final primary = AppTheme.primaryOf(context);
    final pct     = (_downloadProgress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Memuat turun audio… $pct%',
            style: TextStyle(
              fontSize: 12, color: primary, fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 3,
              backgroundColor: primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Surah header (item 0 in list) ─────────────────────────────────────────

  Widget _buildSurahHeader(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    // Surah 1 (Al-Fatihah): Bismillah IS verse 1 — don't repeat it
    // Surah 9 (At-Taubah): no Bismillah at all
    final showBismillah =
        widget.surahNumber != 9 && widget.surahNumber != 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: isDark
              ? [
            primary.withOpacity(0.18),
            primary.withOpacity(0.08),
          ]
              : [
            primary.withOpacity(0.13),
            primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primary.withOpacity(isDark ? 0.2 : 0.18),
        ),
      ),
      child: Column(
        children: [
          // Arabic surah name (calligraphy style)
          Text(
            widget.surahArabic,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize:   44,
              color:      primary,
              height:     1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Latin name + number
          Text(
            '${widget.surahNumber}. ${widget.surahLatin}',
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w900,
              color:      cs.onSurface,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Verse count
          Text(
            '${widget.ayahCount} Ayat',
            style: TextStyle(
              fontSize: 13,
              color:    cs.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),

          if (showBismillah) ...[
            const SizedBox(height: 20),

            // Decorative divider
            Row(
              children: [
                Expanded(child: Divider(color: primary.withOpacity(0.25))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: primary.withOpacity(0.25))),
              ],
            ),

            const SizedBox(height: 16),

            // Bismillah text
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign:     TextAlign.center,
              style: TextStyle(
                fontFamily: kQuranFontFamily,
                fontSize:   26,
                color:      cs.onSurface,
                height:     2.2,
              ),
            ),

            // Bismillah translation
            Text(
              'Dengan Nama Allah Yang Maha Pengasih lagi Maha Penyayang',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:   13,
                fontStyle:  FontStyle.italic,
                color:      cs.onSurface.withOpacity(0.6),
                height:     1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Ornate verse badge ────────────────────────────────────────────────────

  Widget _buildBadge(int ayahNum, bool isPlaying, Color primary) {
    return SizedBox(
      width: 40, height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: _OrnateBadgePainter(primary: primary, isPlaying: isPlaying),
          ),
          Text(
            _toArabicNumerals(ayahNum),
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize:   12,
              fontWeight: FontWeight.bold,
              color: isPlaying ? Colors.white : primary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Verse item ────────────────────────────────────────────────────────────

  Widget _buildAyahItem(BuildContext context, QuranAyah a, int index) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    final isPlaying         = index == _currentPlayIndex;
    final verseRef          = '${widget.surahNumber}:${a.numberInSurah}';
    final translationColor  = cs.onSurface.withOpacity(isDark ? 0.80 : 0.85);
    final actionColor       = cs.onSurface.withOpacity(0.45);
    final activeHighlight   = primary.withOpacity(isDark ? 0.10 : 0.06);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      color: isPlaying ? activeHighlight : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verse header row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
            child: Row(
              children: [
                // Ornate verse badge (tap to play that ayah)
                GestureDetector(
                  onTap: () => _playAyah(index),
                  child: _buildBadge(a.numberInSurah, isPlaying, primary),
                ),
                const SizedBox(width: 10),

                // Verse reference
                Text(
                  verseRef,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      isPlaying ? primary : cs.onSurface.withOpacity(0.6),
                  ),
                ),

                // Playing indicator
                if (isPlaying) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.graphic_eq_rounded, size: 16, color: primary),
                ],

                const Spacer(),

                // Action buttons
                _ayahActionBtn(
                  icon:    Icons.play_circle_outline_rounded,
                  color:   actionColor,
                  onTap:   () => _playAyah(index),
                  tooltip: 'Main ayat ini',
                ),
                _ayahActionBtn(
                  icon:    Icons.bookmark_border_rounded,
                  color:   actionColor,
                  onTap:   () => _bookmarkAyah(a),
                  tooltip: 'Tambah penanda',
                ),
                _ayahActionBtn(
                  icon:    Icons.copy_rounded,
                  color:   actionColor,
                  onTap:   () => _copyAyah(a),
                  tooltip: 'Salin',
                ),
              ],
            ),
          ),

          // ── Arabic text (large, centered, RTL) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: TajweedText(
              text:      a.arabic,
              fontSize:  _arabicSize,
              baseColor: cs.onSurface,
              height:    2.1,
            ),
          ),

          // ── Malay translation ───────────────────────────────────────────
          if (_showTranslation && (a.translationMs?.trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text(
                a.translationMs!,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize:   _malaySize,
                  height:     1.75,
                  fontWeight: FontWeight.w500,
                  color:      translationColor,
                ),
              ),
            ),

          // ── Tafsir / Renungan links ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Row(
              children: [
                _tafsirLink(context, Icons.menu_book_outlined, 'Tafsir'),
                const SizedBox(width: 4),
                Text('|', style: TextStyle(color: cs.onSurface.withOpacity(0.2))),
                const SizedBox(width: 4),
                _tafsirLink(context, Icons.lightbulb_outline, 'Renungan'),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Divider(
              height: 1,
              color: cs.onSurface.withOpacity(isDark ? 0.08 : 0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayahActionBtn({
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
    String?               tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 36, height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _tafsirLink(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label akan ditambah dalam versi akan datang')),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.onSurface.withOpacity(0.38)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color:    cs.onSurface.withOpacity(0.38),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom audio bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isDark    = AppTheme.isDark(context);
    final primary   = AppTheme.primaryOf(context);
    final isActive  = _currentPlayIndex >= 0;
    final barColor  = isDark
        ? const Color(0xFF1A1A2E)
        : Colors.white;

    final totalSec = _duration.inSeconds;
    final posSec   = _position.inSeconds.clamp(0, totalSec > 0 ? totalSec : 1);
    final sliderVal = totalSec > 0 ? posSec / totalSec : 0.0;

    String _fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    final currentAyahLabel = isActive && _ayat.isNotEmpty
        ? 'Ayat ${_ayat[_currentPlayIndex.clamp(0, _ayat.length - 1)].numberInSurah}'
        : widget.surahLatin;

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(
            color: cs.onSurface.withOpacity(isDark ? 0.10 : 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Seek bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // Current position
                  SizedBox(
                    width: 36,
                    child: Text(
                      _fmt(_position),
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),

                  // Slider
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight:          3.0,
                        thumbShape:           const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:         const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor:     primary,
                        inactiveTrackColor:   primary.withOpacity(0.2),
                        thumbColor:           primary,
                        overlayColor:         primary.withOpacity(0.15),
                      ),
                      child: Slider(
                        value: sliderVal.clamp(0.0, 1.0),
                        onChanged: totalSec > 0
                            ? (v) {
                          final seekMs = (v * _duration.inMilliseconds).round();
                          _player.seek(Duration(milliseconds: seekMs));
                        }
                            : null,
                      ),
                    ),
                  ),

                  // Total duration
                  SizedBox(
                    width: 36,
                    child: Text(
                      _fmt(_duration),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Controls row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  // Reciter + verse label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentAyahLabel,
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      isActive ? primary : cs.onSurface,
                          ),
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

                  // Previous ayah
                  _audioBtn(
                    context,
                    icon:  Icons.skip_previous_rounded,
                    size:  22,
                    onTap: isActive ? _previousAyah : null,
                    color: cs.onSurface.withOpacity(isActive ? 0.75 : 0.3),
                  ),
                  const SizedBox(width: 4),

                  // Play / Pause main button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:      primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                          : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size:  28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Next ayah
                  _audioBtn(
                    context,
                    icon:  Icons.skip_next_rounded,
                    size:  22,
                    onTap: isActive ? _nextAyah : null,
                    color: cs.onSurface.withOpacity(isActive ? 0.75 : 0.3),
                  ),
                  const SizedBox(width: 4),

                  // Stop
                  _audioBtn(
                    context,
                    icon:  Icons.stop_rounded,
                    size:  20,
                    onTap: (isActive || _isLoading) ? _stopPlayback : null,
                    color: cs.onSurface.withOpacity((isActive || _isLoading) ? 0.6 : 0.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioBtn(
      BuildContext context, {
        required IconData  icon,
        required double    size,
        required VoidCallback? onTap,
        required Color     color,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40, height: 40,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  // ── Floating Aa button ────────────────────────────────────────────────────

  Widget _floatingAaButton(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final clamped = _clampAa(_aaOffset, size);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve:    Curves.easeOut,
      left:     clamped.dx,
      top:      clamped.dy,
      child: GestureDetector(
        onTap:       _togglePanel,
        onPanUpdate: (d) => setState(() => _aaOffset = _aaOffset + d.delta),
        onPanEnd:    (_) => _snapAa(),
        child: Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: AppTheme.primaryOf(context),
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
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingPanel(BuildContext context) {
    if (!_showAaPanel) return const SizedBox.shrink();
    final size    = MediaQuery.of(context).size;
    final clamped = _clampPanel(_panelOffset, size);
    final isDark  = AppTheme.isDark(context);

    return Positioned(
      left: clamped.dx, top: clamped.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _panelOffset = _panelOffset + d.delta),
        onPanEnd:    (_) => _savePrefs(),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(_glassOpacity),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.14)
                        : Colors.white.withOpacity(0.18),
                  ),
                ),
                child: AaTextSettingsSheet(
                  arabicValue: _arabicValue,
                  malayValue:  _malayValue,
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
                  showTranslation:       _showTranslation,
                  onToggleTranslation: (v) {
                    _haptic();
                    setState(() => _showTranslation = v);
                    _savePrefs();
                  },
                  backgroundOpacity: isDark ? 0.06 : 0.02,
                  margin:            EdgeInsets.zero,
                  useSafeArea:       false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg    = AppTheme.bgOf(context);
    final cs    = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _buildBottomBar(context),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                _buildTajweedLegend(context),
                _buildDownloadBar(context),

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
                          child: Text('Tiada ayat dijumpai.',
                            style: TextStyle(color: cs.onSurface),
                          ),
                        );
                      }

                      // Initial scroll on open
                      if (!_didInitialScroll && widget.initialAyah != null) {
                        _didInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_itemScrollController.isAttached) {
                            _itemScrollController.scrollTo(
                              index: (widget.initialAyah!).clamp(1, ayat.length),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }

                      // +1 for the surah header at index 0
                      return ScrollablePositionedList.builder(
                        itemScrollController:  _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: ayat.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildSurahHeader(context);
                          return _buildAyahItem(context, ayat[index - 1], index - 1);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Dismiss Aa panel tap-away
          if (_showAaPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap:    () => setState(() => _showAaPanel = false),
                child:    const SizedBox.shrink(),
              ),
            ),

          _floatingAaButton(context),
          _floatingPanel(context),
        ],
      ),
    );
  }
}