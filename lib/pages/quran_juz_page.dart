// lib/pages/quran_juz_page.dart
import 'package:flutter/material.dart';

class QuranJuzPage extends StatelessWidget {
  final int juz;
  const QuranJuzPage({super.key, required this.juz});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Juz $juz')),
      body: Center(
        child: Text(
          'Paparan Juz $juz (akan dikemaskini)',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}