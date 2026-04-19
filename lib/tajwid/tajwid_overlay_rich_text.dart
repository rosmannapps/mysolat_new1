// lib/tajwid/tajwid_overlay_rich_text.dart
import 'package:flutter/material.dart';
import 'tajweed_colors.dart';
import 'tajwid_overlay_models.dart';

class TajwidOverlayRichText extends StatelessWidget {
  final String arabic; // plain uthmani text
  final List<TajwidRange> ranges;
  final String fontFamily;
  final double fontSize;
  final double height;
  final TextAlign textAlign;

  const TajwidOverlayRichText({
    super.key,
    required this.arabic,
    required this.ranges,
    required this.fontFamily,
    this.fontSize = 32,
    this.height = 1.55,
    this.textAlign = TextAlign.start,
  });

  String _normalizeForKfgqpc(String s) {
    return s
        .replaceAll('ٲ', 'ا')
    // remove Qur’anic annotation symbols (often render as black circles/dots)
        .replaceAll(RegExp(r'[\u06D6-\u06ED]'), '');
  }

  // Rune-safe slicing
  String _sliceRunes(List<int> runes, int start, int end) {
    if (start < 0) start = 0;
    if (end > runes.length) end = runes.length;
    if (end <= start) return '';
    return String.fromCharCodes(runes.sublist(start, end));
  }

  @override
  Widget build(BuildContext context) {
    final normalColor =
    Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: height,
      color: normalColor,
    );

    final cleaned = _normalizeForKfgqpc(arabic);
    final runes = cleaned.runes.toList();

    // Merge/clip ranges into cleaned text length
    final clipped = <TajwidRange>[];
    for (final r in ranges) {
      final s = r.s.clamp(0, runes.length);
      final e = r.e.clamp(0, runes.length);
      if (e > s) clipped.add(TajwidRange(s: s, e: e, r: r.r));
    }
    clipped.sort((a, b) => a.s.compareTo(b.s));

    // Build spans by alternating normal and colored segments
    final spans = <TextSpan>[];
    int cursor = 0;

    for (final seg in clipped) {
      if (seg.s > cursor) {
        spans.add(TextSpan(
          text: _sliceRunes(runes, cursor, seg.s),
          style: baseStyle.copyWith(color: normalColor),
        ));
      }

      final color = TajweedColors.colorFor(seg.r) ?? normalColor;

      spans.add(TextSpan(
        text: _sliceRunes(runes, seg.s, seg.e),
        style: baseStyle.copyWith(color: color),
      ));

      cursor = seg.e;
    }

    if (cursor < runes.length) {
      spans.add(TextSpan(
        text: _sliceRunes(runes, cursor, runes.length),
        style: baseStyle.copyWith(color: normalColor),
      ));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: textAlign,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        text: TextSpan(style: baseStyle, children: spans),
      ),
    );
  }
}