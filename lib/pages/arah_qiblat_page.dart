// lib/pages/arah_qiblat_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class ArahQiblatPage extends StatefulWidget {
  const ArahQiblatPage({super.key});

  @override
  State<ArahQiblatPage> createState() => _ArahQiblatPageState();
}

class _ArahQiblatPageState extends State<ArahQiblatPage>
    with SingleTickerProviderStateMixin {
  double _qiblaDeg = 292.0;
  static const double _toleranceDeg = 3.0;

  static const Color _bg = Color(0xFFF6F4EF);
  static const Color _ring = Color(0xFFD9DDDC);
  static const Color _tick = Color(0xFF9CA3AF);
  static const Color _cardinal = Color(0xFF111827);
  static const Color _needleOff = Color(0xFF111827);
  static const Color _accent = Color(0xFF1F5E3E);
  static const Color _degreeRed = Color(0xFFD83B2D);

  static const double _dialShiftDown = 78;
  static const double _markerWidth = 5;
  static const double _kaabahSize = 88;
  static const double _kaabahRing = 7;
  static const double _kaabahExtraLift = 72;
  static const double _kaabahImageRotateDeg = -75;
  static const double _smoothAlpha = 0.08;

  StreamSubscription<CompassEvent>? _sub;
  double? _headingDeg;
  double? _smoothHeadingDeg;
  bool _isAligned = false;
  bool _didVibrate = false;
  bool _needsCalibrationHint = false;
  bool _disposed = false;

  // Flash animation
  late final AnimationController _flashCtl;
  late final Animation<double> _flashAnim;

  // Confetti
  late final ConfettiController _confettiCtl;

  @override
  void initState() {
    super.initState();

    // Flash animation controller
    _flashCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtl, curve: Curves.easeOut),
    );

    // Confetti controller
    _confettiCtl = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _updateQiblaFromGps();

    _sub = FlutterCompass.events?.listen((event) {
      if (_disposed) return;
      final h = event.heading;
      if (h == null) return;
      final heading = _norm360(h);
      final prev = _smoothHeadingDeg ?? heading;
      final smoothed = _lerpAngleDeg(prev, heading, _smoothAlpha);
      final aligned = _angleDiffDeg(_qiblaDeg, heading) <= _toleranceDeg;
      final needsHint = _isBadAccuracy(event.accuracy);

      if (_disposed || !mounted) return;
      try {
        setState(() {
          _headingDeg = heading;
          _smoothHeadingDeg = smoothed;
          _isAligned = aligned;
          _needsCalibrationHint = needsHint;
        });
      } catch (_) {}

      if (aligned && !_didVibrate) {
        _didVibrate = true;
        _triggerCelebration();
      } else if (!aligned) {
        _didVibrate = false;
        _stopCelebration();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    _flashCtl.dispose();
    _confettiCtl.dispose();
    super.dispose();
  }

  Future<void> _triggerCelebration() async {
    if (_disposed) return;

    // Triple strong haptic
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    if (_disposed) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    if (_disposed) return;
    await HapticFeedback.heavyImpact();

    // Green flash
    if (_disposed || !mounted) return;
    _flashCtl.forward(from: 0.0);

    // Confetti
    if (_disposed || !mounted) return;
    _confettiCtl.play();
  }

  void _stopCelebration() {
    if (_disposed) return;
    if (_flashCtl.isAnimating) _flashCtl.stop();
    _confettiCtl.stop();
  }

  Future<void> _updateQiblaFromGps() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (_disposed || !mounted) return;
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (_disposed || !mounted) return;
      final qibla = _computeQiblaAngle(pos.latitude, pos.longitude);
      if (_disposed || !mounted) return;
      setState(() => _qiblaDeg = qibla);
    } catch (_) {}
  }

  double _computeQiblaAngle(double lat, double lon) {
    const meccaLat = 21.4225;
    const meccaLon = 39.8262;
    final lat1 = lat * math.pi / 180.0;
    final lat2 = meccaLat * math.pi / 180.0;
    final dLon = (meccaLon - lon) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180.0 / math.pi + 360) % 360;
  }

  static double _norm360(double d) {
    final x = d % 360;
    return x < 0 ? x + 360 : x;
  }

  static double _angleDiffDeg(double a, double b) {
    return (((a - b) + 540) % 360 - 180).abs();
  }

  static double _lerpAngleDeg(double from, double to, double t) {
    final delta = ((to - from) + 540) % 360 - 180;
    return _norm360(from + delta * t);
  }

  static bool _isBadAccuracy(double? acc) {
    if (acc == null) return false;
    if (acc <= 0) return true;
    return acc > 25;
  }

  void _reset() {
    if (_disposed) return;
    setState(() => _didVibrate = false);
    _stopCelebration();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _smoothHeadingDeg ?? _headingDeg ?? 0.0;
    final groupRotationRad = (-heading) * math.pi / 180.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _cardinal),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Qibla: ${_qiblaDeg.toInt()}°',
          style: const TextStyle(
            color: _cardinal,
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: _cardinal),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                const SizedBox(height: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final dialSide =
                          math.min(c.maxWidth, c.maxHeight) * 0.82;
                      final canvasW = dialSide;
                      final canvasH = dialSide + (_dialShiftDown * 2);
                      final size = Size(canvasW, canvasH);
                      final center = Offset(
                          canvasW / 2, dialSide / 2 + _dialShiftDown);
                      final r = dialSide / 2;
                      final dialRadius = r * 0.86;
                      final outerStroke = r * 0.09;
                      final dialTopY =
                          center.dy - dialRadius - outerStroke / 2;
                      final markerTop = math.max(6.0, dialTopY - 26);
                      final markerBottom = dialTopY + 2;
                      final markerHeight =
                          (markerBottom - markerTop).clamp(14.0, 90.0);
                      final qiblaRad =
                          (_qiblaDeg - 90) * math.pi / 180.0;
                      final badgeRadius =
                          dialRadius + outerStroke / 2 + _kaabahExtraLift;
                      final badgeCenter = center +
                          Offset(math.cos(qiblaRad),
                                  math.sin(qiblaRad)) *
                              badgeRadius;
                      final connectorStart = center +
                          Offset(math.cos(qiblaRad),
                                  math.sin(qiblaRad)) *
                              (dialRadius + outerStroke * 0.05);
                      final connectorEnd = center +
                          Offset(math.cos(qiblaRad),
                                  math.sin(qiblaRad)) *
                              (badgeRadius - (_kaabahSize * 0.44));
                      final glowOpacity = _isAligned ? 0.26 : 0.14;

                      return Center(
                        child: SizedBox(
                          width: canvasW,
                          height: canvasH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          _accent
                                              .withOpacity(glowOpacity),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.78],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Green flash overlay
                              AnimatedBuilder(
                                animation: _flashAnim,
                                builder: (_, __) => Positioned.fill(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: (1 - _flashAnim.value) *
                                          0.35,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _accent,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  dialSide / 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              Positioned(
                                top: markerTop,
                                left: center.dx - _markerWidth / 2,
                                child: Container(
                                  width: _markerWidth,
                                  height: markerHeight,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Transform(
                                  alignment: Alignment.topLeft,
                                  transform: Matrix4.identity()
                                    ..translate(center.dx, center.dy)
                                    ..rotateZ(groupRotationRad)
                                    ..translate(
                                        -center.dx, -center.dy),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CustomPaint(
                                        size: size,
                                        painter: _CompassDialPainter(
                                          center: center,
                                          ringColor: _ring,
                                          tickColor: _tick,
                                          cardinalColor: _cardinal,
                                          degreeColor: _degreeRed,
                                          dialRadius: dialRadius,
                                          outerStroke: outerStroke,
                                        ),
                                      ),
                                      CustomPaint(
                                        size: size,
                                        painter: _ConnectorPainter(
                                          start: connectorStart,
                                          end: connectorEnd,
                                          color: _isAligned
                                              ? _accent
                                              : _accent
                                                  .withOpacity(0.70),
                                        ),
                                      ),
                                      CustomPaint(
                                        size: size,
                                        painter: _NeedlePainter(
                                          center: center,
                                          qiblaDeg: _qiblaDeg,
                                          color: _isAligned
                                              ? _accent
                                              : _needleOff,
                                        ),
                                      ),
                                      Positioned(
                                        left: badgeCenter.dx -
                                            (_kaabahSize +
                                                    _kaabahRing * 2) /
                                                2,
                                        top: badgeCenter.dy -
                                            (_kaabahSize +
                                                    _kaabahRing * 2) /
                                                2,
                                        child: _KaabahBadge(
                                          assetPath:
                                              'assets/kaabah.png',
                                          size: _kaabahSize,
                                          ringWidth: _kaabahRing,
                                          ringColor: _isAligned
                                              ? _accent
                                              : _accent
                                                  .withOpacity(0.75),
                                          imageRotateDeg:
                                              _kaabahImageRotateDeg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom card - fixed height
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: double.infinity,
                    height: 80,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isAligned
                          ? _accent.withOpacity(0.15)
                          : Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _isAligned
                            ? _accent.withOpacity(0.5)
                            : Colors.black.withOpacity(0.08),
                        width: _isAligned ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _isAligned
                            ? '🕋  Tepat menghadap Kaabah  ✓'
                            : _needsCalibrationHint
                                ? 'Gerakkan telefon bentuk angka 8\nuntuk kalibrasi kompas'
                                : 'Pusing phone sehingga Kaabah\nberada di atas penanda hijau',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _isAligned ? 17 : 16,
                          fontWeight: FontWeight.w900,
                          color: _isAligned ? _accent : _cardinal,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Confetti — shoots from top center
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtl,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                maxBlastForce: 20,
                minBlastForce: 8,
                emissionFrequency: 0.05,
                gravity: 0.3,
                colors: const [
                  Color(0xFF1F5E3E),
                  Color(0xFF4CAF50),
                  Color(0xFFB68D40),
                  Color(0xFFFFD700),
                  Color(0xFF81C784),
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KaabahBadge extends StatelessWidget {
  final String assetPath;
  final double size;
  final double ringWidth;
  final Color ringColor;
  final double imageRotateDeg;

  const _KaabahBadge({
    required this.assetPath,
    required this.size,
    required this.ringWidth,
    required this.ringColor,
    required this.imageRotateDeg,
  });

  @override
  Widget build(BuildContext context) {
    final outer = size + ringWidth * 2;
    return Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.95),
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Transform.rotate(
            angle: imageRotateDeg * math.pi / 180.0,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  _ConnectorPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter o) =>
      o.start != start || o.end != end || o.color != color;
}

class _NeedlePainter extends CustomPainter {
  final Offset center;
  final double qiblaDeg;
  final Color color;

  _NeedlePainter({
    required this.center,
    required this.qiblaDeg,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final a = (qiblaDeg - 90) * math.pi / 180.0;
    final dir = Offset(math.cos(a), math.sin(a));
    final tip = center + dir * (r * 0.70);
    final tail = center - dir * (r * 0.44);
    Offset perp(Offset v) => Offset(-v.dy, v.dx);
    final p = perp(dir);
    final headW = r * 0.16;
    final tailW = r * 0.10;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final headBase = center + dir * (r * 0.10);
    canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(headBase.dx + p.dx * (headW / 2),
              headBase.dy + p.dy * (headW / 2))
          ..lineTo(headBase.dx - p.dx * (headW / 2),
              headBase.dy - p.dy * (headW / 2))
          ..close(),
        paint);
    final tailBase = center - dir * (r * 0.08);
    canvas.drawPath(
        Path()
          ..moveTo(tail.dx, tail.dy)
          ..lineTo(tailBase.dx + p.dx * (tailW / 2),
              tailBase.dy + p.dy * (tailW / 2))
          ..lineTo(tailBase.dx - p.dx * (tailW / 2),
              tailBase.dy - p.dy * (tailW / 2))
          ..close(),
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true);
    canvas.drawCircle(center, r * 0.055,
        Paint()..color = color..isAntiAlias = true);
    canvas.drawCircle(center, r * 0.040,
        Paint()..color = Colors.white..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter o) =>
      o.center != center || o.qiblaDeg != qiblaDeg || o.color != color;
}

class _CompassDialPainter extends CustomPainter {
  final Offset center;
  final Color ringColor;
  final Color tickColor;
  final Color cardinalColor;
  final Color degreeColor;
  final double dialRadius;
  final double outerStroke;

  _CompassDialPainter({
    required this.center,
    required this.ringColor,
    required this.tickColor,
    required this.cardinalColor,
    required this.degreeColor,
    required this.dialRadius,
    required this.outerStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = dialRadius / 0.86;
    canvas.drawCircle(center, dialRadius,
        Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true);
    canvas.drawCircle(
        center,
        dialRadius,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerStroke
          ..isAntiAlias = true);
    final inner = Paint()
      ..color = Colors.black.withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.008
      ..isAntiAlias = true;
    canvas.drawCircle(center, r * 0.40, inner);
    canvas.drawCircle(center, r * 0.48, inner);
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = r * 0.012
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final majorPaint = Paint()
      ..color = Colors.black.withOpacity(0.70)
      ..strokeWidth = r * 0.020
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (int deg = 0; deg < 360; deg += 3) {
      final isMajor = deg % 45 == 0;
      final isMid = deg % 15 == 0;
      final len = isMajor ? r * 0.11 : (isMid ? r * 0.075 : r * 0.045);
      final a = (deg - 90) * math.pi / 180.0;
      final p1 = center +
          Offset(math.cos(a), math.sin(a)) * (dialRadius - r * 0.05);
      final p2 = center +
          Offset(math.cos(a), math.sin(a)) * (dialRadius - r * 0.05 - len);
      canvas.drawLine(p1, p2, isMajor ? majorPaint : tickPaint);
    }
    _drawCardinal(canvas, r, 270, 'W');
    _drawCardinal(canvas, r, 0, 'N');
    _drawCardinal(canvas, r, 90, 'E');
    _drawCardinal(canvas, r, 180, 'S');
    for (final d in <int>[45, 90, 135, 180, 225, 270, 315, 360]) {
      _drawDegreeLabel(canvas, r, d == 360 ? 0 : d, '$d°');
    }
  }

  void _drawCardinal(Canvas canvas, double r, int deg, String text) {
    final angle = (deg - 90) * math.pi / 180.0;
    final pos =
        center + Offset(math.cos(angle), math.sin(angle)) * (r * 0.56);
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: r * 0.16,
              fontWeight: FontWeight.w900,
              color: cardinalColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + math.pi / 2);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawDegreeLabel(Canvas canvas, double r, int deg, String text) {
    final angle = (deg - 90) * math.pi / 180.0;
    final pos =
        center + Offset(math.cos(angle), math.sin(angle)) * (r * 0.98);
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: r * 0.050,
              fontWeight: FontWeight.w500,
              color: degreeColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle + math.pi / 2);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter o) =>
      o.center != center ||
      o.ringColor != ringColor ||
      o.tickColor != tickColor ||
      o.cardinalColor != cardinalColor ||
      o.degreeColor != degreeColor ||
      o.dialRadius != dialRadius ||
      o.outerStroke != outerStroke;
}
