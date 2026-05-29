// lib/pages/surah_detail_page.dart
//
// Thin redirect — forwards straight to QuranReaderPage.
// All logic lives in quran_reader_page.dart.

import 'package:flutter/material.dart';
import 'quran_reader_page.dart';

class SurahDetailPage extends StatelessWidget {
  final int    number;
  final String nameLatin;
  final String nameArabic;
  final int    ayahCount;
  final int?   initialAyah;

  const SurahDetailPage({
    super.key,
    required this.number,
    required this.nameLatin,
    required this.nameArabic,
    required this.ayahCount,
    this.initialAyah,
  });

  @override
  Widget build(BuildContext context) {
    // Immediately show the reader — no intermediate screen.
    return QuranReaderPage(
      surahNumber: number,
      surahLatin:  nameLatin,
      surahArabic: nameArabic,
      ayahCount:   ayahCount,
      initialAyah: initialAyah,
    );
  }
}