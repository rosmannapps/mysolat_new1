// lib/pages/surah_detail_page.dart
import 'package:flutter/material.dart';

class SurahDetailPage extends StatelessWidget {
  final int number;
  final String nameLatin;
  final String nameArabic;

  const SurahDetailPage({
    super.key,
    required this.number,
    required this.nameLatin,
    required this.nameArabic,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('$number · $nameLatin')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nameArabic, style: t.displaySmall, textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Text(nameLatin, style: t.titleLarge),
            const SizedBox(height: 16),
            Text(
              'Paparan Surah (akan dikemaskini)',
              style: t.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}