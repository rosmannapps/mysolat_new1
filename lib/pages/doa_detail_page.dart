// lib/pages/doa_detail_page.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/aa_text_settings_sheet.dart';

// ✅ Keep your Quran font
const String kQuranFontFamily = 'KFGQPC';

class DoaDetailPage extends StatefulWidget {
  final String categoryTitle;
  final String assetPath;

  const DoaDetailPage({
    super.key,
    required this.categoryTitle,
    required this.assetPath,
  });

  @override
  State<DoaDetailPage> createState() => _DoaDetailPageState();
}

class _DoaDetailPageState extends State<DoaDetailPage> {
  late Future<List<DoaItem>> _futureDoa;

  // Translation state
  bool _showTranslation = true;

  // SINGLE source of truth (numbers match actual font sizes)
  int _arabicValue = 28;
  int _malayValue = 18;

  double get _arabicSize => _arabicValue.toDouble();
  double get _malaySize => _malayValue.toDouble();

  // Floating "Aa" button state
  Offset _aaOffset = const Offset(300, 520);

  // Floating settings panel state
  bool _showAaPanel = false;
  Offset _panelOffset = const Offset(24, 420);

  // Glass tuning (lower = clearer background)
  static const double _glassOpacity = 0.12;

  // Pref keys
  String get _prefsPrefix => 'doa_detail_v1_${widget.assetPath.hashCode}';
  String get _kArabic => '${_prefsPrefix}_arabic';
  String get _kMalay => '${_prefsPrefix}_malay';
  String get _kShowTrans => '${_prefsPrefix}_show_translation';
  String get _kAaDx => '${_prefsPrefix}_aa_dx';
  String get _kAaDy => '${_prefsPrefix}_aa_dy';

  @override
  void initState() {
    super.initState();
    _futureDoa = _loadDoaFromAsset(widget.assetPath);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final a = p.getInt(_kArabic);
      final m = p.getInt(_kMalay);
      final st = p.getBool(_kShowTrans);
      final dx = p.getDouble(_kAaDx);
      final dy = p.getDouble(_kAaDy);

      if (!mounted) return;
      setState(() {
        if (a != null) _arabicValue = a.clamp(20, 44);
        if (m != null) _malayValue = m.clamp(12, 28);
        if (st != null) _showTranslation = st;
        if (dx != null && dy != null) _aaOffset = Offset(dx, dy);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kArabic, _arabicValue);
      await p.setInt(_kMalay, _malayValue);
      await p.setBool(_kShowTrans, _showTranslation);
      await p.setDouble(_kAaDx, _aaOffset.dx);
      await p.setDouble(_kAaDy, _aaOffset.dy);
    } catch (_) {
      // ignore
    }
  }

  Future<List<DoaItem>> _loadDoaFromAsset(String path) async {
    final jsonStr = await rootBundle.loadString(path);
    final data = json.decode(jsonStr) as List<dynamic>;
    return data.map((e) => DoaItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------------------------------------------------------------------------
  // FLOATING "Aa" BUTTON + FLOATING PANEL
  // ---------------------------------------------------------------------------

  void _toggleAaPanel() {
    final size = MediaQuery.of(context).size;

    setState(() {
      _showAaPanel = !_showAaPanel;

      if (_showAaPanel) {
        const double margin = 10;
        const double targetW = 340;
        const double estimatedH = 200;

        final double panelW = (size.width - margin * 2).clamp(260.0, targetW);

        final double dx = (_aaOffset.dx - panelW + 54).clamp(margin, size.width - panelW - margin);
        final double dy = (_aaOffset.dy - 10).clamp(margin, size.height - estimatedH - margin);

        _panelOffset = Offset(dx, dy);
      }
    });
  }

  void _snapAaToEdge() {
    final size = MediaQuery.of(context).size;
    const double margin = 10;
    const double w = 54;
    const double h = 54;

    final bool snapRight = _aaOffset.dx > (size.width / 2);
    final double targetDx = snapRight ? (size.width - w - margin) : margin;

    final double dy = _aaOffset.dy.clamp(margin, size.height - h - margin);

    setState(() {
      _aaOffset = Offset(targetDx, dy);
    });
    _savePrefs();
  }

  Widget _aaCircle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: cs.primary, // ✅ follow app theme (green)
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
      child: Text(
        'Aa',
        style: TextStyle(
          color: cs.onPrimary, // ✅ readable on primary
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _floatingAaButton() {
    final size = MediaQuery.of(context).size;
    const double margin = 10;
    const double w = 54;
    const double h = 54;

    final dx = _aaOffset.dx.clamp(margin, size.width - w - margin);
    final dy = _aaOffset.dy.clamp(margin, size.height - h - margin);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: dx,
      top: dy,
      child: GestureDetector(
        onTap: _toggleAaPanel,
        onPanUpdate: (d) {
          setState(() {
            final nx = (_aaOffset.dx + d.delta.dx).clamp(margin, size.width - w - margin);
            final ny = (_aaOffset.dy + d.delta.dy).clamp(margin, size.height - h - margin);
            _aaOffset = Offset(nx.toDouble(), ny.toDouble());
          });
        },
        onPanEnd: (_) => _snapAaToEdge(),
        child: _aaCircle(context),
      ),
    );
  }

  Widget _floatingAaPanel() {
    if (!_showAaPanel) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    const double margin = 10;
    const double targetW = 340;
    const double estimatedH = 200;

    final cs = Theme.of(context).colorScheme;

    final double panelW = (size.width - margin * 2).clamp(260.0, targetW);

    final dx = _panelOffset.dx.clamp(margin, size.width - panelW - margin);
    final dy = _panelOffset.dy.clamp(margin, size.height - estimatedH - margin);

    return Positioned(
      left: dx,
      top: dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final nx = (_panelOffset.dx + d.delta.dx).clamp(margin, size.width - panelW - margin);
            final ny = (_panelOffset.dy + d.delta.dy).clamp(margin, size.height - estimatedH - margin);
            _panelOffset = Offset(nx.toDouble(), ny.toDouble());
          });
        },
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: panelW,
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(_glassOpacity),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cs.onSurface.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: AaTextSettingsSheet(
                  arabicValue: _arabicValue,
                  malayValue: _malayValue,
                  onArabicMinus: () {
                    setState(() => _arabicValue = (_arabicValue - 1).clamp(20, 44));
                    _savePrefs();
                  },
                  onArabicPlus: () {
                    setState(() => _arabicValue = (_arabicValue + 1).clamp(20, 44));
                    _savePrefs();
                  },
                  onMalayMinus: () {
                    setState(() => _malayValue = (_malayValue - 1).clamp(12, 28));
                    _savePrefs();
                  },
                  onMalayPlus: () {
                    setState(() => _malayValue = (_malayValue + 1).clamp(12, 28));
                    _savePrefs();
                  },
                  showTranslationToggle: true,
                  showTranslation: _showTranslation,
                  onToggleTranslation: (v) {
                    setState(() => _showTranslation = v);
                    _savePrefs();
                  },
                  // inner sheet transparency (outer container is the "glass")
                  backgroundOpacity: 0.02,
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
  // UI HELPERS
  // ---------------------------------------------------------------------------

  Widget _circleButton({required Widget child, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withOpacity(0.92), // ✅ follow theme (no forced white)
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 54, height: 54, child: Center(child: child)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface, // ✅ follow app theme (no more brown page)
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: back (left)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Row(
                    children: [
                      _circleButton(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: cs.onSurface,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      // (No fixed Aa here — floating Aa replaces it)
                      const SizedBox(width: 54),
                    ],
                  ),
                ),

                // Big title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                  child: Text(
                    widget.categoryTitle,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      height: 1.02,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: FutureBuilder<List<DoaItem>>(
                    future: _futureDoa,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: cs.primary),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Gagal memuatkan doa.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurface),
                            ),
                          ),
                        );
                      }

                      final items = snapshot.data ?? <DoaItem>[];
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Tiada doa dijumpai.',
                            style: TextStyle(color: cs.onSurface.withOpacity(0.70)),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 34),
                        itemBuilder: (context, index) => _buildDoaBlock(
                          context,
                          items[index],
                          cs,
                          isDark,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Tap outside closes the panel
          if (_showAaPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showAaPanel = false),
                child: const SizedBox.shrink(),
              ),
            ),

          _floatingAaButton(),
          _floatingAaPanel(),
        ],
      ),
    );
  }

  Widget _buildDoaBlock(BuildContext context, DoaItem d, ColorScheme cs, bool isDark) {
    final titleSize = (20.0).clamp(18, 26);
    final arabicSize = _arabicSize;
    final translationSize = _malaySize;
    final referenceSize = (_malaySize - 1).clamp(12, 22);

    // ✅ Theme-following colors:
    // - Arabic: onSurface (readable)
    // - Translation: primary (your light green accent)
    // - Reference: onSurface faded
    final titleColor = cs.onSurface;
    final arabicColor = cs.onSurface;
    final translationColor = cs.primary;
    final referenceColor = cs.onSurface.withOpacity(isDark ? 0.65 : 0.70);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          d.title,
          style: TextStyle(
            fontSize: titleSize.toDouble(),
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 10),

        // Arabic
        Text(
          d.arabic,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: arabicSize,
            height: 1.9,
            color: arabicColor,
            fontFamily: kQuranFontFamily,
          ),
        ),

        // Malay translation
        if (_showTranslation && (d.translation?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 18),
          Text(
            d.translation!,
            style: TextStyle(
              fontSize: translationSize,
              height: 1.55,
              fontWeight: FontWeight.w700,
              color: translationColor, // ✅ light green (primary)
            ),
          ),
        ],

        // Reference
        if (_showTranslation && (d.reference?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 14),
          Text(
            d.reference!,
            style: TextStyle(
              fontSize: referenceSize.toDouble(),
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: referenceColor,
            ),
          ),
        ],
      ],
    );
  }
}

class DoaItem {
  final String title;
  final String arabic;
  final String? latin;
  final String? translation;
  final String? reference;

  DoaItem({
    required this.title,
    required this.arabic,
    this.latin,
    this.translation,
    this.reference,
  });

  factory DoaItem.fromJson(Map<String, dynamic> json) {
    return DoaItem(
      title: json['title'] as String? ?? '',
      arabic: json['arabic'] as String? ?? '',
      latin: json['latin'] as String?,
      translation: json['translation'] as String?,
      reference: json['reference'] as String?,
    );
  }
}