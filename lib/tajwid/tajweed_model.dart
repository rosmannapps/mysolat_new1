import 'package:flutter/material.dart';

/// One colored segment of text (a run).
class TajweedSpan {
  final String text;
  final String? rule; // e.g. "ham_wasl", "madda_normal"
  final Color? color;

  const TajweedSpan({
    required this.text,
    this.rule,
    this.color,
  });
}

/// One ayah (verse) after tajweed parsing.
class TajweedAyah {
  final int ayahNumber;
  final List<TajweedSpan> spans;

  const TajweedAyah({
    required this.ayahNumber,
    required this.spans,
  });
}