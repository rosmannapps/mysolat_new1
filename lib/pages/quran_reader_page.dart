// lib/pages/quran_reader_page.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import '../services/quran_audio_service.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../services/bookmark_storage.dart';
import '../services/prefs_service.dart';
import '../tajweed_text.dart';
import '../theme/app_theme.dart';
import '../widgets/aa_text_settings_sheet.dart';

const String kQuranFontFamily = 'KFGQPC';

class QuranAyah {
  final int numberInSurah;

  /// Arabic text — contains tajweed HTML markup when available,
  /// e.g. <tajweed class=ham_wasl>ٱ</tajweed>
  /// TajweedText/TajweedParser renders this with colors.
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

  // ── Tajweed JSON cache (shared across page instances) ─────────────────
  static Map<String, dynamic>? _tajweedJsonCache;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _didInitialScroll = false;

  bool _showTranslation = true;
  int  _arabicValue = 28;
  int  _malayValue  = 15;

  static const int _aMin = 20;
  static const int _aMax = 44;
  static const int _mMin = 12;
  static const int _mMax = 28;

  double get _arabicSize => _arabicValue.toDouble();
  double get _malaySize  => _malayValue.toDouble();

  Offset _aaOffset    = const Offset(300, 520);
  bool   _showAaPanel = false;
  Offset _panelOffset = const Offset(24, 420);

  static const double _glassOpacity = 0.055;

  String get _prefs      => 'quran_reader_theme_v1';
  String get _kArabic    => '$_prefs.arabic';
  String get _kMalay     => '$_prefs.malay';
  String get _kShowTrans => '$_prefs.trans';
  String get _kAaDx      => '$_prefs.aa_dx';
  String get _kAaDy      => '$_prefs.aa_dy';
  String get _kPanelDx   => '$_prefs.panel_dx';
  String get _kPanelDy   => '$_prefs.panel_dy';

  // ── Audio recitation ──────────────────────────────────────────────────
  // The surah MP3 is downloaded to device storage on first play.
  // After that it's read from disk — smooth as a local file, zero network
  // dependency during playback.
  // positionStream (~200ms) maps current position → ayah index → scroll.

  final AudioPlayer _player           = AudioPlayer();
  List<QuranAyah>   _ayat             = [];
  List<AyahTiming>  _timings          = [];
  int               _currentPlayIndex = -1;
  bool              _isPlaying        = false;
  bool              _isLoading        = false;
  double            _downloadProgress = 0.0;

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

      // Seek to the requested ayah if needed
      Duration startPos = Duration.zero;
      if (startAyah > 1 && _timings.isNotEmpty) {
        final t = _timings.firstWhere(
          (t) => t.ayahNumber == startAyah,
          orElse: () => _timings.first,
        );
        startPos = Duration(milliseconds: t.startMs);
      }

      // Play from LOCAL file — no streaming, no buffering gaps
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

  // ── Lifecycle ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _futureAyat = _loadSurah(widget.surahNumber);
    _loadPrefs();

    // positionStream fires ~every 200ms while playing.
    // We map the current playback position → ayah index via timestamp data.
    // This drives highlighting + auto-scroll WITHOUT touching the audio.
    _player.positionStream.listen((pos) {
      if (!mounted || _timings.isEmpty) return;
      final ms    = pos.inMilliseconds;
      final index = QuranAudioService.instance
          .ayahIndexAtPosition(_timings, ms);
      if (index >= 0 && index != _currentPlayIndex) {
        setState(() => _currentPlayIndex = index);
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index:    index,
            duration: const Duration(milliseconds: 400),
            curve:    Curves.easeInOut,
          );
        }
      }
    });

    // Mirror player playing state.
    _player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    });

    // Reset UI when surah finishes.
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying        = false;
          _isLoading        = false;
          _currentPlayIndex = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ── Preferences ──────────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final p = PrefsService.instance;
    if (!mounted) return;
    setState(() {
      _arabicValue = (p.getInt(_kArabic) ?? 28).clamp(_aMin, _aMax);
      _malayValue  = (p.getInt(_kMalay)  ?? 15).clamp(_mMin, _mMax);
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
    await p.setInt(_kMalay,  _malayValue);
    await p.setBool(_kShowTrans, _showTranslation);
    await p.setDouble(_kAaDx, _aaOffset.dx);
    await p.setDouble(_kAaDy, _aaOffset.dy);
    await p.setDouble(_kPanelDx, _panelOffset.dx);
    await p.setDouble(_kPanelDy, _panelOffset.dy);
  }

  // ── Surah loader ─────────────────────────────────────────────────────
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
    final raw    = await rootBundle.loadString(
      'assets/quran/surahs/surah_$padded.json',
    );
    final decoded = jsonDecode(raw);
    final List list = decoded is List ? decoded : (decoded['ayahs'] ?? []);

    final result  = <QuranAyah>[];
    int   fallback = 1;

    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final dynNo = m['numberInSurah'] ?? m['ayahNumber'] ?? m['number'] ?? fallback;
      final no    = dynNo is int ? dynNo : int.tryParse(dynNo.toString()) ?? fallback;

      final arabic = tajweedMap[no] ??
          (m['arabic_tajweed'] ?? m['arabic'] ?? m['textUthmani'] ?? m['text'] ?? '')
              .toString()
              .trim();

      if (arabic.isEmpty) continue;

      if (surahNumber == 2 && no == 1) {
        debugPrint('DEBUG SURAH 2 AYAH 1 ARABIC = $arabic');
      }

      final trans = (m['ms'] ?? m['translationMs'] ?? m['translation'] ?? m['malay'])
          ?.toString();

      result.add(QuranAyah(
        numberInSurah: no,
        arabic:        arabic,
        translationMs: (trans?.trim().isNotEmpty ?? false) ? trans : null,
      ));

      fallback++;
    }

    // Cache ayat for audio playback
    _ayat = result;

    return result;
  }

  // ── UI helpers ───────────────────────────────────────────────────────
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
    const w = 54.0, h = 54.0;
    return Offset(
      o.dx.clamp(margin, size.width  - w - margin).toDouble(),
      o.dy.clamp(margin, size.height - h - margin).toDouble(),
    );
  }

  Offset _clampPanelToScreen(Offset o, Size size) {
    const margin = 10.0;
    const w = 320.0, h = 230.0;
    return Offset(
      o.dx.clamp(margin, size.width  - w - margin).toDouble(),
      o.dy.clamp(margin, size.height - h - margin).toDouble(),
    );
  }

  void _snapAaToEdge() {
    final size      = MediaQuery.of(context).size;
    const margin    = 10.0;
    const w         = 54.0;
    final snapRight = _aaOffset.dx > size.width / 2;
    setState(() {
      _aaOffset = _clampAaToScreen(
        Offset(snapRight ? size.width - w - margin : margin, _aaOffset.dy),
        size,
      );
    });
    _savePrefs();
  }

  void _haptic() => HapticFeedback.selectionClick();

  // ── Ayah actions ─────────────────────────────────────────────────────
  Future<void> _bookmarkAyah(QuranAyah ayah) async {
    await BookmarkStorage.addOrUpdate(Bookmark(
      surahNumber: widget.surahNumber,
      surahLatin:  widget.surahLatin,
      surahArabic: widget.surahArabic,
      ayahNumber:  ayah.numberInSurah,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Penanda disimpan • ${widget.surahLatin} ayat ${ayah.numberInSurah}',
      ),
    ));
  }

  void _copyAyah(QuranAyah ayah) async {
    await Clipboard.setData(ClipboardData(
      text: '${ayah.arabic}\n\n${ayah.translationMs ?? ''}\n\n'
          '(${widget.surahLatin} ${ayah.numberInSurah})',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayat disalin')),
    );
  }

  void _shareAyah(QuranAyah ayah) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fungsi share akan ditambah')),
    );
  }

  void _noteAyah(QuranAyah ayah) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fungsi nota akan ditambah')),
    );
  }

  // ── Download options ─────────────────────────────────────────────────

  void _showDownloadOptions() {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    showModalBottomSheet(
      context:       context,
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
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Muat Turun Audio',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.surahLatin,
              style: TextStyle(
                fontSize: 13, color: cs.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            // Option 1 — Full Surah
            _downloadOptionTile(
              context:     context,
              icon:        Icons.music_note_rounded,
              title:       'Muat Turun Surah Penuh',
              subtitle:    'Satu fail audio berterusan — tilawah lancar tanpa henti. '
                           'Sesuai untuk bacaan sambil mengikut ayat.',
              recommended: true,
              onTap: () {
                Navigator.pop(context);
                _startPlayback();   // download + play immediately
              },
            ),
            const SizedBox(height: 12),

            // Option 2 — Per Ayah
            _downloadOptionTile(
              context:     context,
              icon:        Icons.format_list_numbered_rounded,
              title:       'Muat Turun Per Ayat',
              subtitle:    'Setiap ayat disimpan berasingan — sesuai untuk ulangan '
                           'ayat tertentu atau hafazan.',
              recommended: false,
              onTap: () {
                Navigator.pop(context);
                _downloadPerAyah();
              },
            ),
            const SizedBox(height: 8),

            // Info note
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: cs.onSurface.withOpacity(0.38)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Audio yang dimuat turun disimpan dalam peranti. '
                      'Ia tidak perlu dimuat turun semula.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.4),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadOptionTile(
    BuildContext context, {
    required IconData icon,
    required String   title,
    required String   subtitle,
    required bool     recommended,
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
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Disyor',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.55),
                      height: 1.4,
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

  /// Download every ayah individually (for per-verse playback / memorisation).
  Future<void> _downloadPerAyah() async {
    if (_ayat.isEmpty) return;

    final total = _ayat.length;
    int   done  = 0;

    setState(() { _isLoading = true; _downloadProgress = 0; });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Memuat turun $total ayat untuk ${widget.surahLatin}…'),
      duration: const Duration(seconds: 2),
    ));

    try {
      await QuranAudioService.instance.downloadPerAyah(
        surahNumber: widget.surahNumber,
        ayahCount:   total,
        onProgress: (i) {
          done = i;
          if (mounted) setState(() => _downloadProgress = done / total);
        },
      );

      if (mounted) {
        setState(() { _isLoading = false; _downloadProgress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✓ $total ayat ${widget.surahLatin} berjaya dimuat turun.',
          ),
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

  // ── Subwidgets ───────────────────────────────────────────────────────

  /// Recitation control bar shown below the page header.
  Widget _recitationBar(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    final isActive   = _currentPlayIndex >= 0;
    final isDownloading = _isLoading && _downloadProgress < 1.0;
    final pct        = (_downloadProgress * 100).toInt();
    final ayahLabel  = isDownloading
        ? 'Memuat… $pct%'
        : isActive
            ? 'Ayat ${_ayat[_currentPlayIndex].numberInSurah}'
            : 'Tilawah';

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : primary.withOpacity(0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download progress bar (only visible while downloading)
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  minHeight: 3,
                  backgroundColor: primary.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              ),
            ),
          Row(
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
          ),
          const SizedBox(width: 14),

          // Status label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ayahLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isActive ? primary : cs.onSurface,
                  ),
                ),
                if (isActive && !_isLoading)
                  Text(
                    widget.surahLatin,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
              ],
            ),
          ),

          // Stop button (only when active)
          if (isActive)
            GestureDetector(
              onTap: _stopPlayback,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.stop_rounded,
                  size: 20,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            ),
        ],
          ), // Row
        ],
      ), // Column
    );
  }

  Widget _header(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final primary = AppTheme.primaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () { _stopPlayback(); Navigator.of(context).maybePop(); },
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: cs.onSurface),
            ),
          ),
          const SizedBox(width: 12),

          // Surah title — fully visible, wraps if needed
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.surahNumber}. ${widget.surahLatin}',
                  textAlign: TextAlign.center,
                  // No maxLines / ellipsis — always fully shown
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.surahArabic}  •  ${widget.ayahCount} ayat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Download options button
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _showDownloadOptions,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.download_rounded, size: 22, color: primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayahActionButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _aaCircle(BuildContext context) {
    return Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color: AppTheme.primaryOf(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10, offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'Aa',
        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _floatingAaButton(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final clamped = _clampAaToScreen(_aaOffset, size);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      left: clamped.dx, top: clamped.dy,
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
    final size    = MediaQuery.of(context).size;
    final clamped = _clampPanelToScreen(_panelOffset, size);
    final isDark  = AppTheme.isDark(context);
    return Positioned(
      left: clamped.dx, top: clamped.dy,
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
                  showTranslation: _showTranslation,
                  onToggleTranslation: (v) {
                    _haptic();
                    setState(() => _showTranslation = v);
                    _savePrefs();
                  },
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

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bg               = AppTheme.bgOf(context);
    final cs               = Theme.of(context).colorScheme;
    final isDark           = AppTheme.isDark(context);
    final primary          = AppTheme.primaryOf(context);
    final arabicColor      = cs.onSurface;
    final translationColor = cs.onSurface.withOpacity(isDark ? 0.82 : 0.88);
    final cardColor        = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final borderColor      = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(context),
                _recitationBar(context),
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
                            'Tiada ayat dijumpai.',
                            style: TextStyle(color: cs.onSurface),
                          ),
                        );
                      }

                      if (!_didInitialScroll && widget.initialAyah != null) {
                        _didInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_itemScrollController.isAttached) {
                            _itemScrollController.scrollTo(
                              index: (widget.initialAyah! - 1)
                                  .clamp(0, ayat.length - 1),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }

                      return ScrollablePositionedList.builder(
                        itemScrollController:   _itemScrollController,
                        itemPositionsListener:  _itemPositionsListener,
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                        itemCount: ayat.length,
                        itemBuilder: (context, index) {
                          final a          = ayat[index];
                          final isPlaying  = index == _currentPlayIndex;

                          // Highlight card that is currently being recited
                          final activeCardColor = isDark
                              ? primary.withOpacity(0.14)
                              : primary.withOpacity(0.08);
                          final activeBorder = primary.withOpacity(0.45);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                color:  isPlaying ? activeCardColor : cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPlaying ? activeBorder : borderColor,
                                  width: isPlaying ? 1.6 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isPlaying
                                        ? primary.withOpacity(0.12)
                                        : Colors.black.withOpacity(isDark ? 0.14 : 0.04),
                                    blurRadius: isPlaying ? 16 : 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── Ayah number + action buttons ──
                                  Row(
                                    children: [
                                      // Tap number badge to play that specific ayah
                                      GestureDetector(
                                        onTap: () => _playAyah(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPlaying
                                                ? primary.withOpacity(0.18)
                                                : isDark
                                                    ? Colors.white.withOpacity(0.08)
                                                    : AppTheme.primarySoft,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isPlaying) ...[
                                                Icon(
                                                  Icons.graphic_eq_rounded,
                                                  size: 13,
                                                  color: primary,
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                '${a.numberInSurah}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppTheme.primaryOf(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      _ayahActionButton(
                                        icon: Icons.bookmark_border,
                                        onTap: () => _bookmarkAyah(a),
                                      ),
                                      _ayahActionButton(
                                        icon: Icons.copy_rounded,
                                        onTap: () => _copyAyah(a),
                                      ),
                                      _ayahActionButton(
                                        icon: Icons.share_outlined,
                                        onTap: () => _shareAyah(a),
                                      ),
                                      _ayahActionButton(
                                        icon: Icons.edit_note_rounded,
                                        onTap: () => _noteAyah(a),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 34),

                                  // ── Tajweed-coloured Arabic text ──
                                  TajweedText(
                                    text:      a.arabic,
                                    fontSize:  _arabicSize,
                                    baseColor: arabicColor,
                                    height:    2.05,
                                  ),

                                  // ── Malay translation ─────────────
                                  if (_showTranslation &&
                                      (a.translationMs?.trim().isNotEmpty ?? false)) ...[
                                    const SizedBox(height: 22),
                                    Text(
                                      a.translationMs!,
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize:   _malaySize,
                                        height:     1.75,
                                        fontWeight: FontWeight.w500,
                                        color:      translationColor,
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
