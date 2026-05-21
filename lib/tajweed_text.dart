import 'package:flutter/material.dart';

const Map<String, Color> kTajweedColors = {
  'ham_wasl': Color(0xFF9AA0A6),
  'slnt': Color(0xFF9AA0A6),
  'laam_shamsiyah': Color(0xFF9AA0A6),

  'madda_normal': Color(0xFF537FFF),
  'madda_permissible': Color(0xFF4050FF),
  'madda_necessary': Color(0xFF000EBC),
  'madda_obligatory': Color(0xFF2144C1),
  'madda_o': Color(0xFF2144C1),

  'qlq': Color(0xFFDD0008),

  'ikhf_shfw': Color(0xFFD500B7),
  'ikhf': Color(0xFF9400A8),

  'idghm_shfw': Color(0xFF58B800),
  'iqlb': Color(0xFF26BFFD),
  'idgh_ghn': Color(0xFF169777),
  'idgh_w_ghn': Color(0xFF169200),
  'idgh_mus': Color(0xFFA1A1A1),

  'ghn': Color(0xFFFF7E1E),
};

List<InlineSpan> parseTajweed(String input) {
  input = input.replaceAll(RegExp(r'<span class=end>.*?</span>'), '');

  final spans = <InlineSpan>[];

  final regex = RegExp(
    r'<tajweed class="?([\w_]+)"?>(.*?)</tajweed>',
    dotAll: true,
  );

  int currentIndex = 0;

  for (final match in regex.allMatches(input)) {
    if (match.start > currentIndex) {
      final normalText = input.substring(currentIndex, match.start);
      if (normalText.isNotEmpty) {
        spans.add(TextSpan(text: normalText));
      }
    }

    final className = match.group(1) ?? '';
    final innerText = match.group(2) ?? '';
    final color = kTajweedColors[className];

    spans.add(
      TextSpan(
        text: innerText,
        style: color == null ? null : TextStyle(color: color),
      ),
    );

    currentIndex = match.end;
  }

  if (currentIndex < input.length) {
    final remaining = input.substring(currentIndex);
    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining));
    }
  }

  return spans;
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
        children: parseTajweed(text),
      ),
    );
  }
}