import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../widgets/aa_text_settings_sheet.dart';
import '../theme/app_theme.dart';

const String kQuranFontFamily = 'KFGQPC';

class QuranReaderPage extends StatefulWidget {
  final int surahNumber;
  final String titleLatin;
  final String titleArabic;

  const QuranReaderPage({
    super.key,
    required this.surahNumber,
    required this.titleLatin,
    required this.titleArabic,
  });

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  late Future<List<_Ayah>> _futureAyat;

  int _arabicValue = 32;
  int _malayValue = 15;

  Offset _aaOffset = const Offset(280, 520);
  double _aaOpacity = 0.88;

  bool _showAaPanel = false;
  Offset _panelOffset = const Offset(28, 410);

  @override
  void initState() {
    super.initState();
    _futureAyat = _loadAyat(widget.surahNumber);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureOffsetsOnScreen();
    });
  }

  Future<List<_Ayah>> _loadAyat(int surah) async {
    final file =
        'assets/quran/surahs/surah_${surah.toString().padLeft(3, '0')}.json';

    final raw = await rootBundle.loadString(file);
    final List<dynamic> data = json.decode(raw) as List<dynamic>;

    return data
        .map(
          (e) => _Ayah(
        number: (e['ayah'] as int?) ?? 0,
        arabic: (e['arabic'] ?? '').toString(),
        malay: (e['malay'] ?? '').toString(),
      ),
    )
        .toList();
  }

  Offset _clampOffset({
    required Offset value,
    required Size screen,
    required Size itemSize,
    double margin = 10,
  }) {
    final dx = value.dx.clamp(margin, screen.width - itemSize.width - margin);
    final dy = value.dy.clamp(margin, screen.height - itemSize.height - margin);
    return Offset(dx.toDouble(), dy.toDouble());
  }

  void _ensureOffsetsOnScreen() {
    final screen = MediaQuery.of(context).size;

    const aaSize = Size(54, 54);

    if (_aaOffset.dx > screen.width) {
      _aaOffset = Offset(
        screen.width - aaSize.width - 12,
        screen.height - aaSize.height - 120,
      );
    }

    setState(() {});
  }

  void _toggleAaPanel() {
    setState(() {
      _showAaPanel = !_showAaPanel;
    });
  }

  Widget _floatingAaButton(Color primary) {
    const double aaSize = 54;

    return Positioned(
      left: _aaOffset.dx,
      top: _aaOffset.dy,
      child: GestureDetector(
        onTap: _toggleAaPanel,
        onPanUpdate: (d) {
          final screen = MediaQuery.of(context).size;

          setState(() {
            _aaOffset = _clampOffset(
              value: _aaOffset + d.delta,
              screen: screen,
              itemSize: const Size(aaSize, aaSize),
            );
          });
        },
        child: Opacity(
          opacity: _aaOpacity,
          child: Container(
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
          ),
        ),
      ),
    );
  }

  Widget _floatingAaPanel() {
    if (!_showAaPanel) return const SizedBox.shrink();

    const double panelW = 320;

    return Positioned(
      left: _panelOffset.dx,
      top: _panelOffset.dy,
      child: _GlassPanel(
        width: panelW,
        child: AaTextSettingsSheet(
          arabicValue: _arabicValue,
          malayValue: _malayValue,
          onArabicMinus: () => setState(() => _arabicValue--),
          onArabicPlus: () => setState(() => _arabicValue++),
          onMalayMinus: () => setState(() => _malayValue--),
          onMalayPlus: () => setState(() => _malayValue++),
          showTranslationToggle: false,
          showTranslation: true,
          onToggleTranslation: (_) {},
          backgroundOpacity: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final primary = cs.primary;
    final gold = AppTheme.gold;
    final surface = cs.surface;
    final textColor = cs.onSurface;

    final arabicScale = _arabicValue / 32;
    final malayScale = _malayValue / 15;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: primary,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.titleLatin,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.titleArabic,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: kQuranFontFamily,
                                fontSize: 40 * arabicScale,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: FutureBuilder<List<_Ayah>>(
                    future: _futureAyat,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final ayat = snap.data!;

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: ayat.length,
                        itemBuilder: (context, i) {
                          return _AyahCard(
                            ayah: ayat[i],
                            arabicScale: arabicScale,
                            malayScale: malayScale,
                            surface: surface,
                            primary: primary,
                            gold: gold,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          _floatingAaButton(primary),
          _floatingAaPanel(),
        ],
      ),
    );
  }
}

class _Ayah {
  final int number;
  final String arabic;
  final String malay;

  const _Ayah({
    required this.number,
    required this.arabic,
    required this.malay,
  });
}

class _AyahCard extends StatelessWidget {
  final _Ayah ayah;
  final double arabicScale;
  final double malayScale;

  final Color surface;
  final Color primary;
  final Color gold;

  const _AyahCard({
    required this.ayah,
    required this.arabicScale,
    required this.malayScale,
    required this.surface,
    required this.primary,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Text(
              ayah.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: kQuranFontFamily,
                fontSize: 32 * arabicScale,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ayah.malay,
              style: TextStyle(
                fontSize: 15 * malayScale,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Ayat ${ayah.number}',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final double width;

  const _GlassPanel({
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }
}