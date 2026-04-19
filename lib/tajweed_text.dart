import 'package:flutter/material.dart';

/// Map tajweed CSS class -> colour
/// (Colours based on the Tajweed Guide)
const Map<String, Color> kTajweedColors = {
  'ham_wasl': Color(0xFFAAAAAA),
  'slnt': Color(0xFFAAAAAA),
  'laam_shamsiyah': Color(0xFFAAAAAA),

  'madda_normal': Color(0xFF537FFF),
  'madda_permissible': Color(0xFF4050FF),
  'madda_necessary': Color(0xFF000EBC),
  'madda_obligatory': Color(0xFF2144C1),
  'madda_o': Color(0xFF2144C1), // sometimes named like this

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

/// Parse a string that contains tags like
///
///   <tajweed class=ham_wasl>ٱ</tajweed>
///   <tajweed class="madda_normal">ـٰ</tajweed>
///
/// into a list of InlineSpans with colours.
List<InlineSpan> parseTajweed(String input) {
  // 1) Remove verse number span, e.g. <span class=end>١</span>
  input = input.replaceAll(RegExp(r'<span class=end>.*?</span>'), '');

  final spans = <InlineSpan>[];

  // 2) Match <tajweed class=xxx>...</tajweed>
  //    Supports with OR without quotes around the class name.
  final regex = RegExp(
    r'<tajweed class="?([\w_]+)"?>(.*?)</tajweed>',
    dotAll: true,
  );

  int currentIndex = 0;

  for (final match in regex.allMatches(input)) {
    // Normal text before this tajweed segment
    if (match.start > currentIndex) {
      final normalText = input.substring(currentIndex, match.start);
      if (normalText.isNotEmpty) {
        spans.add(TextSpan(text: normalText));
      }
    }

    final className = match.group(1) ?? '';
    final innerText = match.group(2) ?? '';

    final color = kTajweedColors[className] ?? Colors.black;

    spans.add(
      TextSpan(
        text: innerText,
        style: TextStyle(color: color),
      ),
    );

    currentIndex = match.end;
  }

  // Any remaining text after the last match
  if (currentIndex < input.length) {
    final remaining = input.substring(currentIndex);
    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining));
    }
  }

  return spans;
}

/// A ready-to-use widget that shows one ayah with tajweed colours
class TajweedText extends StatelessWidget {
  final String text;

  const TajweedText({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'KFGQPC',
          fontSize: 32,
          height: 2.0,
          color: Colors.black,
        ),
        children: parseTajweed(text),
      ),
    );
  }
}