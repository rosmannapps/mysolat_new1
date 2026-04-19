// lib/tajwid/tajwid_rich_text.dart
import 'package:flutter/material.dart';

import 'tajwid_parser.dart';
import 'tajweed_colors.dart';

class TajwidRichText extends StatelessWidget {
  final String tajwidMarkup;
  final String fontFamily;
  final double fontSize;
  final double height;
  final TextAlign textAlign;

  /// If false -> render everything in normalColor (no tajwid coloring),
  /// but still parse <span class=end> markers correctly.
  final bool enableColors;

  const TajwidRichText({
    super.key,
    required this.tajwidMarkup,
    required this.fontFamily,
    this.fontSize = 36,
    this.height = 2.0,
    this.textAlign = TextAlign.center,
    this.enableColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = TajweedParser.parse(tajwidMarkup);

    final normalColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    final children = <TextSpan>[];

    for (final s in parsed.spans) {
      final rule = s.rule;

      // Ayah end marker
      if (rule == 'end') {
        children.add(
          TextSpan(
            text: ' ${s.text} ',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize * 0.85,
              height: height,
              color: normalColor.withOpacity(0.55),
            ),
          ),
        );
        continue;
      }

      // No tajwid colors (plain black), OR colored by rule
      final c = enableColors
          ? (TajweedColors.colorFor(rule ?? '') ?? normalColor)
          : normalColor;

      children.add(
        TextSpan(
          text: s.text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSize,
            height: height,
            color: c,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(children: children),
      ),
    );
  }
}