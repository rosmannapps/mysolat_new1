// lib/quran_module/al_quran_app/tajwid/tajwid_rich_text.dart
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

  /// When set, the word at this 1-based index (counting spaces) gets a
  /// highlight background — used for word-by-word recitation tracking.
  final int? highlightedWordIndex;

  const TajwidRichText({
    super.key,
    required this.tajwidMarkup,
    required this.fontFamily,
    this.fontSize = 36,
    this.height = 2.0,
    this.textAlign = TextAlign.center,
    this.enableColors = true,
    this.highlightedWordIndex,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = TajweedParser.parse(tajwidMarkup);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalColor = isDark ? Colors.white : Colors.black;

    final children = <TextSpan>[];
    int wordIdx = 1; // 1-based word counter

    for (final s in parsed.spans) {
      final rule = s.rule;

      // Ayah end marker — never highlighted, always dim
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

      final baseColor = enableColors
          ? (TajweedColors.colorFor(rule ?? '') ?? normalColor)
          : normalColor;

      // Split by spaces to respect word boundaries.
      // Each space increments wordIdx; parts between spaces share the same word.
      final parts = s.text.split(' ');

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];

        if (part.isNotEmpty) {
          final isHighlighted =
              highlightedWordIndex != null && wordIdx == highlightedWordIndex;

          children.add(
            TextSpan(
              text: part,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize,
                height: height,
                color: isHighlighted ? Colors.white : baseColor,
                backgroundColor: isHighlighted
                    ? (isDark
                        ? Colors.green.shade700.withOpacity(0.85)
                        : Colors.green.shade600.withOpacity(0.80))
                    : null,
              ),
            ),
          );
        }

        // Space between parts = word boundary → advance word counter
        if (i < parts.length - 1) {
          children.add(TextSpan(
            text: ' ',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: height,
            ),
          ));
          wordIdx++;
        }
      }
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
