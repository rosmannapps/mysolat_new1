// lib/tajweed_text.dart
import 'package:flutter/material.dart';

import 'tajwid/tajwid_parser.dart';

const Map<String, Color> kTajweedColors = {
  'ham_wasl':         Color(0xFF9AA0A6),
  'slnt':             Color(0xFF9AA0A6),
  'laam_shamsiyah':   Color(0xFF9AA0A6),

  'madda_normal':     Color(0xFF537FFF),
  'madda_permissible':Color(0xFF4050FF),
  'madda_necessary':  Color(0xFF000EBC),
  'madda_obligatory': Color(0xFF2144C1),
  'madda_o':          Color(0xFF2144C1),

  'qlq':              Color(0xFFDD0008),

  'ikhf_shfw':        Color(0xFFD500B7),
  'ikhf':             Color(0xFF9400A8),

  'idghm_shfw':       Color(0xFF58B800),
  'iqlb':             Color(0xFF26BFFD),
  'idgh_ghn':         Color(0xFF169777),
  'idgh_w_ghn':       Color(0xFF169200),
  'idgh_mus':         Color(0xFFA1A1A1),

  'ghn':              Color(0xFFFF7E1E),

  'end':              Color(0xFF9E9E9E),
};

List<InlineSpan> buildTajweedSpans({
  required String input,
  required Color baseColor,
}) {
  final parsed = TajweedParser.parse(input);

  // ── DEBUG: log first call so we can see what's happening ──────────────
  if (parsed.spans.isNotEmpty) {
    final colored = parsed.spans.where((s) => s.rule != null).length;
    debugPrint(
      'TajweedText: ${parsed.spans.length} spans, $colored colored | '
          'first rule=${parsed.spans.first.rule ?? "null"} '
          'text="${parsed.spans.first.text.length > 8 ? parsed.spans.first.text.substring(0, 8) : parsed.spans.first.text}"',
    );
  } else {
    debugPrint('TajweedText: 0 spans — input was: '
        '"${input.length > 60 ? input.substring(0, 60) : input}"');
  }
  // ── END DEBUG ──────────────────────────────────────────────────────────

  return parsed.spans.map((s) {
    final color = s.rule == null
        ? baseColor
        : (kTajweedColors[s.rule!] ?? baseColor);

    return TextSpan(
      text: s.text,
      style: TextStyle(color: color),
    );
  }).toList();
}

class TajweedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color baseColor;
  final double height;
  final TextAlign textAlign;

  const TajweedText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.baseColor,
    this.height = 2.15,
    this.textAlign = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'KFGQPC',
          fontSize: fontSize,
          height: height,
          color: baseColor,
        ),
        children: buildTajweedSpans(
          input: text,
          baseColor: baseColor,
        ),
      ),
    );
  }
}