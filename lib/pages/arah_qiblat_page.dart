// lib/pages/arah_qiblat_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

class ArahQiblatPage extends StatefulWidget {
  const ArahQiblatPage({super.key});

  @override
  State<ArahQiblatPage> createState() => _ArahQiblatPageState();
}

class _ArahQiblatPageState extends State<ArahQiblatPage>
    with SingleTickerProviderStateMixin {
  static const double _qiblaDeg = 292.0;
  static const double _toleranceDeg = 3.0;

  static const Color _bg = Color(0xFFF6F4EF);
  static const Color _ring = Color(0xFFD9DDDC);
  static const Color _tick = Color(0xFF9CA3AF);
  static const Color _cardinal = Color(0xFF111827);
  static const Color _needleOff = Color(0xFF111827);
  static const Color _accent = Color(0xFF1F5E3E);
  static const Color _degreeRed = Color(0xFFD83B2D);

  // Dial layout
  static const double _dialShiftDown = 78;

  // Fixed marker line
  static const double _markerWidth = 5;

  // Kaabah badge
  static const double _kaabahSize = 88;
  static const double _kaabahRing = 7;

  // ✅ move badge higher (outside dial) so marker tip touches badge bottom when aligned
  static const double _kaabahExtraLift = 72;

  // ✅ rotate image (your tuned value)
  static const double _kaabahImageRotateDeg = -75;

  // ✅ smooth rotation strength: lower = smoother, higher = snappier
  static const double _smoothAlpha = 0.18;

  StreamSubscription<CompassEvent>? _sub;

  double? _headingDeg; // raw
  double? _smoothHeadingDeg; // smoothed

  bool _isAligned = false;
  bool _didVibrate = false;

  // calibration hint
  bool _needsCalibrationHint = false;

  late final AnimationController _pulseCtl;

  @override
  void initState() {
    super.initState();

    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _sub = FlutterCompass.events?.listen((event) {
      final h = event.heading;
      if (h == null) return;

      final heading = _norm360(h);

      // ---- smooth heading (low-pass filter, safe)
      final prev = _smoothHeadingDeg ?? heading;
      final smoothed = _lerpAngleDeg(prev, heading, _smoothAlpha);

      // aligned when heading ~= qibla (marker fixed)
      final aligned = _angleDiffDeg(_qiblaDeg, heading) <= _toleranceDeg;

      // optional calibration hint (defensive: accuracy can be null)
      final acc = event.accuracy;
      final needsHint = _isBadAccuracy(acc);

      if (!mounted) return;
      setState(() {
        _headingDeg = heading;
        _smoothHeadingDeg = smoothed;
        _isAligned = aligned;
        _needsCalibrationHint = needsHint;
      });

      if (aligned && !_didVibrate) {
        _didVibrate = true;
        HapticFeedback.mediumImpact();
        _startPulse();
      } else if (!aligned) {
        _didVibrate = false;
        _stopPulse();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtl.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  static double _norm360(double d) {
    final x = d % 360;
    return x < 0 ? x + 360 : x;
  }

  static double _angleDiffDeg(double a, double b) {
    final d = ((a - b) + 540) % 360 - 180;
    return d.abs();
  }

  static double _lerpAngleDeg(double from, double to, double t) {
    final delta = ((to - from) + 540) % 360 - 180;
    return _norm360(from + delta * t);
  }

  static bool _isBadAccuracy(double? acc) {
    if (acc == null) return false;
    if (acc <= 0) return true; // unknown/invalid readings on some devices
    return acc > 25; // degrees; bigger = worse
  }

  void _startPulse() {
    if (_pulseCtl.isAnimating) return;
    _pulseCtl.repeat(reverse: true);
  }

  void _stopPulse() {
    if (!_pulseCtl.isAnimating) return;
    _pulseCtl.stop();
    _pulseCtl.value = 0;
  }

  void _reset() {
    setState(() => _didVibrate = false);
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
        child: Column(
          children: [
            const SizedBox(height: 4
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final dialSide = math.min(c.maxWidth, c.maxHeight) * 0.82;
                  final canvasW = dialSide;
                  final canvasH = dialSide + (_dialShiftDown * 2);

                  final size = Size(canvasW, canvasH);
                  final center = Offset(canvasW / 2, dialSide / 2 + _dialShiftDown);

                  final r = dialSide / 2;
                  final dialRadius = r * 0.86;
                  final outerStroke = r * 0.09;

                  final dialTopY = center.dy - dialRadius - outerStroke / 2;

                  // fixed marker just above dial
                  final markerTop = math.max(6.0, dialTopY - 26);
                  final markerBottom = dialTopY + 2;
                  final markerHeight = (markerBottom - markerTop).clamp(14.0, 90.0);

                  // qibla position in dial coordinates
                  final qiblaRad = (_qiblaDeg - 90) * math.pi / 180.0;

                  // badge radius (outside dial)
                  final badgeRadius = dialRadius + outerStroke / 2 + _kaabahExtraLift;

                  // badge center in dial space
                  final badgeCenter =
                      center + Offset(math.cos(qiblaRad), math.sin(qiblaRad)) * badgeRadius;

                  // connector line from dial edge to badge (dial space)
                  final connectorStart = center +
                      Offset(math.cos(qiblaRad), math.sin(qiblaRad)) *
                          (dialRadius + outerStroke * 0.05);
                  final connectorEnd = center +
                      Offset(math.cos(qiblaRad), math.sin(qiblaRad)) *
                          (badgeRadius - (_kaabahSize * 0.44));

                  final glowOpacity = _isAligned ? 0.26 : 0.14;

                  return Center(
                    child: SizedBox(
                      width: canvasW,
                      height: canvasH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // background soft glow (existing)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      _accent.withOpacity(glowOpacity),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.78],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // FIXED marker (does not rotate)
                          Positioned(
                            top: markerTop,
                            left: center.dx - _markerWidth / 2,
                            child: Container(
                              width: _markerWidth,
                              height: markerHeight,
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),

                          // ROTATING group: dial + connector + needle + kaabah
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.topLeft,
                              transform: Matrix4.identity()
                                ..translate(center.dx, center.dy)
                                ..rotateZ(groupRotationRad)
                                ..translate(-center.dx, -center.dy),
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

                                  // ✅ pulsing inner glow when aligned (micro polish)
                                  if (_isAligned)
                                    CustomPaint(
                                      size: size,
                                      painter: _PulseGlowPainter(
                                        repaint: _pulseCtl,
                                        center: center,
                                        radius: dialRadius * 0.94,
                                        color: _accent,
                                      ),
                                    ),

                                  CustomPaint(
                                    size: size,
                                    painter: _ConnectorPainter(
                                      start: connectorStart,
                                      end: connectorEnd,
                                      color: _isAligned ? _accent : _accent.withOpacity(0.70),
                                    ),
                                  ),

                                  CustomPaint(
                                    size: size,
                                    painter: _NeedlePainter(
                                      center: center,
                                      qiblaDeg: _qiblaDeg,
                                      color: _isAligned ? _accent : _needleOff,
                                    ),
                                  ),

                                  Positioned(
                                    left: badgeCenter.dx - (_kaabahSize + _kaabahRing * 2) / 2,
                                    top: badgeCenter.dy - (_kaabahSize + _kaabahRing * 2) / 2,
                                    child: _KaabahBadge(
                                      assetPath: 'assets/kaabah.png',
                                      size: _kaabahSize,
                                      ringWidth: _kaabahRing,
                                      ringColor: _isAligned ? _accent : _accent.withOpacity(0.75),
                                      imageRotateDeg: _kaabahImageRotateDeg,
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

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isAligned
                            ? 'Tepat menghadap Kaabah'
                            : 'Pusing phone sehingga\nposisi kaabah\nberada di tengah',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _isAligned ? _accent : _cardinal,
                          height: 1.10,
                        ),
                      ),
                      // ✅ optional calibration hint (no layout jump)
                      if (!_isAligned && _needsCalibrationHint) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Gerakkan telefon dalam bentuk angka 8\nuntuk kalibrasi kompas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _cardinal.withOpacity(0.70),
                            height: 1.10,
                          ),
                        ),
                      ],
                    ],
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

/// ✅ Pulsing inner glow (only used when aligned)
class _PulseGlowPainter extends CustomPainter {
  final Listenable repaint;
  final Offset center;
  final double radius;
  final Color color;

  _PulseGlowPainter({
    required this.repaint,
    required this.center,
    required this.radius,
    required this.color,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // value 0..1
    final v = (repaint as Animation<double>).value;
    final strength = 0.20 + (v * 0.10);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(strength),
          color.withOpacity(strength * 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseGlowPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.repaint != repaint;
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
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(start, end, p);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.color != color;
  }
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
    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headBase.dx + p.dx * (headW / 2), headBase.dy + p.dy * (headW / 2))
      ..lineTo(headBase.dx - p.dx * (headW / 2), headBase.dy - p.dy * (headW / 2))
      ..close();
    canvas.drawPath(headPath, paint);

    final tailBase = center - dir * (r * 0.08);
    final tailPath = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(tailBase.dx + p.dx * (tailW / 2), tailBase.dy + p.dy * (tailW / 2))
      ..lineTo(tailBase.dx - p.dx * (tailW / 2), tailBase.dy - p.dy * (tailW / 2))
      ..close();

    final tailPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(tailPath, tailPaint);

    final hubOuter = Paint()..color = color..isAntiAlias = true;
    final hubInner = Paint()..color = Colors.white..isAntiAlias = true;

    canvas.drawCircle(center, r * 0.055, hubOuter);
    canvas.drawCircle(center, r * 0.040, hubInner);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.qiblaDeg != qiblaDeg ||
        oldDelegate.color != color;
  }
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

    final outerRing = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..isAntiAlias = true;

    final face = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, dialRadius, face);
    canvas.drawCircle(center, dialRadius, outerRing);

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
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (dialRadius - r * 0.05);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * (dialRadius - r * 0.05 - len);

      canvas.drawLine(p1, p2, isMajor ? majorPaint : tickPaint);
    }

    _drawCardinal(canvas, r, 270, 'W');
    _drawCardinal(canvas, r, 0, 'N');
    _drawCardinal(canvas, r, 90, 'E');
    _drawCardinal(canvas, r, 180, 'S');

    final labels = <int>[45, 90, 135, 180, 225, 270, 315, 360];
    for (final d in labels) {
      _drawDegreeLabel(canvas, r, d == 360 ? 0 : d, '$d°');
    }
  }

  void _drawCardinal(Canvas canvas, double r, int deg, String text) {
    final angle = (deg - 90) * math.pi / 180.0;
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * (r * 0.56);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: r * 0.16,
          fontWeight: FontWeight.w900,
          color: cardinalColor,
        ),
      ),
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
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * (r * 0.98);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: r * 0.050,
          fontWeight: FontWeight.w500,
          color: degreeColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rot = angle + math.pi / 2;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rot);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.cardinalColor != cardinalColor ||
        oldDelegate.degreeColor != degreeColor ||
        oldDelegate.dialRadius != dialRadius ||
        oldDelegate.outerStroke != outerStroke;
  }
}