// lib/pages/zikir_page.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/aa_text_settings_sheet.dart';

class ZikirPage extends StatefulWidget {
  const ZikirPage({super.key});

  @override
  State<ZikirPage> createState() => _ZikirPageState();
}

class _ZikirPageState extends State<ZikirPage> {
  // Optional premium accent (small details only)
  static const Color _gold = Color(0xFFD6B35B);

  // ✅ Single source of truth (numbers = real sizes)
  int _arabicValue = 26;
  int _malayValue = 15;

  double get _arabicSize => _arabicValue.toDouble();
  double get _malaySize => _malayValue.toDouble();

  // Toggle translation (Malay)
  bool _showMalay = true;

  // Latin (we force OFF for Selepas Solat)
  bool _showLatin = true;

  // Helpers
  double get _platformScale => Platform.isAndroid ? 0.92 : 1.0;

  // Floating "Aa" button state
  Offset _aaOffset = const Offset(300, 520);

  // Floating settings panel state
  bool _showAaPanel = false;
  Offset _panelOffset = const Offset(24, 420);

  // Glass tuning (lower = more transparent)
  double _glassOpacity = 0.10;

  // Pref keys
  String get _prefsPrefix => 'zikir_page_v2_theme';
  String get _kArabic => '${_prefsPrefix}_arabic';
  String get _kMalay => '${_prefsPrefix}_malay';
  String get _kShowMalay => '${_prefsPrefix}_show_malay';
  String get _kAaDx => '${_prefsPrefix}_aa_dx';
  String get _kAaDy => '${_prefsPrefix}_aa_dy';
  String get _kPanelDx => '${_prefsPrefix}_panel_dx';
  String get _kPanelDy => '${_prefsPrefix}_panel_dy';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final a = p.getInt(_kArabic);
      final m = p.getInt(_kMalay);
      final sm = p.getBool(_kShowMalay);
      final dx = p.getDouble(_kAaDx);
      final dy = p.getDouble(_kAaDy);
      final pdx = p.getDouble(_kPanelDx);
      final pdy = p.getDouble(_kPanelDy);

      if (!mounted) return;
      setState(() {
        if (a != null) _arabicValue = a.clamp(18, 40);
        if (m != null) _malayValue = m.clamp(11, 26);
        if (sm != null) _showMalay = sm;
        if (dx != null && dy != null) _aaOffset = Offset(dx, dy);
        if (pdx != null && pdy != null) _panelOffset = Offset(pdx, pdy);
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
      await p.setBool(_kShowMalay, _showMalay);
      await p.setDouble(_kAaDx, _aaOffset.dx);
      await p.setDouble(_kAaDy, _aaOffset.dy);
      await p.setDouble(_kPanelDx, _panelOffset.dx);
      await p.setDouble(_kPanelDy, _panelOffset.dy);
    } catch (_) {
      // ignore
    }
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
        const double estimatedH = 220;

        final double panelW = (size.width - margin * 2).clamp(260.0, targetW);

        final double dx = (_aaOffset.dx - panelW + 54).clamp(margin, size.width - panelW - margin);
        final double dy = (_aaOffset.dy - 10).clamp(margin, size.height - estimatedH - margin);

        _panelOffset = Offset(dx, dy);
      }
    });

    _savePrefs();
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

  void _haptic() => HapticFeedback.selectionClick();

  Widget _aaCircle({
    required bool isDark,
    required Color primary,
    required Color shadowColor,
  }) {
    // Premium: primary circle + subtle gold ring
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: _gold.withOpacity(isDark ? 0.78 : 0.88),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 8),
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
          height: 1.0,
        ),
      ),
    );
  }

  Widget _floatingAaButton({
    required bool isDark,
    required Color primary,
    required Color shadowColor,
  }) {
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
        child: _aaCircle(isDark: isDark, primary: primary, shadowColor: shadowColor),
      ),
    );
  }

  Widget _floatingAaPanel({
    required bool isDark,
    required Color glassBg,
    required Color glassBorder,
    required Color panelShadow,
  }) {
    if (!_showAaPanel) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    const double margin = 10;
    const double targetW = 340;
    const double estimatedH = 220;

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
        onPanEnd: (_) => _savePrefs(),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: panelW,
                decoration: BoxDecoration(
                  color: glassBg.withOpacity(_glassOpacity),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: glassBorder.withOpacity(isDark ? 0.28 : 0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: panelShadow,
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
                    setState(() => _arabicValue = (_arabicValue - 1).clamp(18, 40));
                    _savePrefs();
                  },
                  onArabicPlus: () {
                    _haptic();
                    setState(() => _arabicValue = (_arabicValue + 1).clamp(18, 40));
                    _savePrefs();
                  },
                  onMalayMinus: () {
                    _haptic();
                    setState(() => _malayValue = (_malayValue - 1).clamp(11, 26));
                    _savePrefs();
                  },
                  onMalayPlus: () {
                    _haptic();
                    setState(() => _malayValue = (_malayValue + 1).clamp(11, 26));
                    _savePrefs();
                  },
                  showTranslationToggle: true,
                  showTranslation: _showMalay,
                  onToggleTranslation: (v) {
                    _haptic();
                    setState(() => _showMalay = v);
                    _savePrefs();
                  },
                  // Inner sheet is subtle; outer container is the glass
                  backgroundOpacity: isDark ? 0.08 : 0.05,
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
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeScale = mq.textScaleFactor.clamp(1.0, 1.1);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Base colors from AppTheme (light) + ColorScheme (dark)
    final bg = theme.scaffoldBackgroundColor;
    final surface = cs.surface;

    // Some Flutter versions don't expose surfaceVariant/surfaceContainer* reliably,
    // so we derive a soft "inner" surface ourselves.
    final inner = isDark
        ? Colors.white.withOpacity(0.06)
        : AppTheme.primarySoft;

    final rail = isDark
        ? Colors.white.withOpacity(0.06)
        : AppTheme.primarySoft;

    final border = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);

    final textPrimary = cs.onSurface;
    final textSecondary = cs.onSurface.withOpacity(0.62);

    final shadow = isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.10);
    final panelShadow = isDark ? Colors.black.withOpacity(0.60) : Colors.black.withOpacity(0.14);

    // Glass colors (for panel)
    final glassBg = isDark ? Colors.black : Colors.white;
    final glassBorder = isDark ? Colors.white : Colors.white;

    final primary = AppTheme.primary;

    return MediaQuery(
      data: mq.copyWith(textScaleFactor: safeScale),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              // Main page content
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row (Aa is floating)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Zikir Harian',
                                  style: TextStyle(
                                    fontSize: 30 * _platformScale,
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                    height: 1.0,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 56),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Tabs rail
                          Container(
                            height: 50,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: rail,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: border),
                            ),
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: border),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadow,
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: textPrimary,
                              unselectedLabelColor: textSecondary,
                              overlayColor: WidgetStateProperty.all(Colors.transparent),
                              tabs: const [
                                Tab(
                                  child: Text(
                                    'SELEPAS\nSOLAT',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Tab(
                                  child: Text(
                                    'PAGI',
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Tab(
                                  child: Text(
                                    'PETANG',
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              labelStyle: TextStyle(
                                fontSize: 14 * _platformScale,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: 0.2,
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontSize: 14 * _platformScale,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _ZikirList(
                          primary: primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          bgColor: bg,
                          cardColor: surface,
                          innerColor: inner,
                          stroke: border,
                          shadowColor: shadow,
                          gold: _gold,
                          assetPath: 'assets/zikir/zikir_selepas_solat.json',
                          showLatin: false,
                          showMalay: _showMalay,
                          arabicSize: _arabicSize * _platformScale,
                          malaySize: _malaySize * _platformScale,
                          isDark: isDark,
                        ),
                        _ZikirList(
                          primary: primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          bgColor: bg,
                          cardColor: surface,
                          innerColor: inner,
                          stroke: border,
                          shadowColor: shadow,
                          gold: _gold,
                          assetPath: 'assets/zikir/zikir_pagi.json',
                          showLatin: _showLatin,
                          showMalay: _showMalay,
                          arabicSize: _arabicSize * _platformScale,
                          malaySize: _malaySize * _platformScale,
                          isDark: isDark,
                        ),
                        _ZikirList(
                          primary: primary,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          bgColor: bg,
                          cardColor: surface,
                          innerColor: inner,
                          stroke: border,
                          shadowColor: shadow,
                          gold: _gold,
                          assetPath: 'assets/zikir/zikir_petang.json',
                          showLatin: _showLatin,
                          showMalay: _showMalay,
                          arabicSize: _arabicSize * _platformScale,
                          malaySize: _malaySize * _platformScale,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Tap-catcher (close panel)
              if (_showAaPanel)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (_) => setState(() => _showAaPanel = false),
                    child: const SizedBox.expand(),
                  ),
                ),

              // Floating draggable Aa
              _floatingAaButton(isDark: isDark, primary: primary, shadowColor: panelShadow),

              // Floating settings panel
              _floatingAaPanel(
                isDark: isDark,
                glassBg: glassBg,
                glassBorder: glassBorder,
                panelShadow: panelShadow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= DATA MODEL =======================
class ZikirItem {
  final String title;
  final String arabic;
  final String? latin;
  final String? translation;

  ZikirItem({
    required this.title,
    required this.arabic,
    this.latin,
    this.translation,
  });

  factory ZikirItem.fromJson(Map<String, dynamic> json) {
    return ZikirItem(
      title: (json['title'] ?? '').toString(),
      arabic: (json['arabic'] ?? '').toString(),
      latin: json['latin']?.toString(),
      translation: json['translation']?.toString(),
    );
  }
}

// ======================= LIST UI =======================
class _ZikirList extends StatefulWidget {
  final String assetPath;
  final bool showLatin;
  final bool showMalay;
  final double arabicSize;
  final double malaySize;

  final Color bgColor;
  final Color cardColor;
  final Color innerColor;
  final Color stroke;
  final Color shadowColor;
  final Color gold;
  final Color primary;

  final Color textPrimary;
  final Color textSecondary;

  final bool isDark;

  const _ZikirList({
    required this.assetPath,
    required this.showLatin,
    required this.showMalay,
    required this.arabicSize,
    required this.malaySize,
    required this.bgColor,
    required this.cardColor,
    required this.innerColor,
    required this.stroke,
    required this.shadowColor,
    required this.gold,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  State<_ZikirList> createState() => _ZikirListState();
}

class _ZikirListState extends State<_ZikirList> {
  late Future<List<ZikirItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ZikirList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _future = _load();
    }
  }

  Future<List<ZikirItem>> _load() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => ZikirItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.bgColor,
      child: FutureBuilder<List<ZikirItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.primary),
              ),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Tiada data zikir.',
                style: TextStyle(
                  color: widget.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final it = items[i];
              return _ZikirCard(
                it: it,
                showLatin: widget.showLatin,
                showMalay: widget.showMalay,
                arabicSize: widget.arabicSize,
                malaySize: widget.malaySize,
                cardColor: widget.cardColor,
                innerColor: widget.innerColor,
                stroke: widget.stroke,
                shadowColor: widget.shadowColor,
                gold: widget.gold,
                primary: widget.primary,
                textPrimary: widget.textPrimary,
                textSecondary: widget.textSecondary,
                isDark: widget.isDark,
              );
            },
          );
        },
      ),
    );
  }
}

// ======================= CARD UI =======================
class _ZikirCard extends StatelessWidget {
  final ZikirItem it;
  final bool showLatin;
  final bool showMalay;
  final double arabicSize;
  final double malaySize;

  final Color cardColor;
  final Color innerColor;
  final Color stroke;
  final Color shadowColor;
  final Color gold;
  final Color primary;

  final Color textPrimary;
  final Color textSecondary;

  final bool isDark;

  const _ZikirCard({
    required this.it,
    required this.showLatin,
    required this.showMalay,
    required this.arabicSize,
    required this.malaySize,
    required this.cardColor,
    required this.innerColor,
    required this.stroke,
    required this.shadowColor,
    required this.gold,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasLatin = (it.latin ?? '').trim().isNotEmpty;
    final hasMalay = (it.translation ?? '').trim().isNotEmpty;

    // Arabic should feel "ink"-like and readable in both modes
    final arabicColor = isDark ? textPrimary.withOpacity(0.92) : AppTheme.text;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + tiny premium dot
          Row(
            children: [
              Expanded(
                child: Text(
                  it.title,
                  style: TextStyle(
                    fontSize: 23 * (Platform.isAndroid ? 0.95 : 1.0),
                    fontWeight: FontWeight.w900,
                    color: primary,
                    height: 1.05,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: gold.withOpacity(isDark ? 0.78 : 0.88),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Arabic
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              it.arabic,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'KFGQPC',
                fontSize: arabicSize,
                height: 1.95,
                letterSpacing: 0.15,
                wordSpacing: 2.0,
                color: arabicColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Latin (optional)
          if (showLatin && hasLatin) ...[
            const SizedBox(height: 14),
            Text(
              it.latin!.trim(),
              style: TextStyle(
                fontSize: (malaySize + 1).clamp(12, 22),
                height: 1.5,
                color: textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Malay translation (toggle)
          if (showMalay && hasMalay) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: stroke.withOpacity(0.9)),
              ),
              child: Text(
                it.translation!.trim(),
                style: TextStyle(
                  fontSize: malaySize,
                  height: 1.55,
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}