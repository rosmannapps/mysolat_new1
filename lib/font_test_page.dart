import 'package:flutter/material.dart';

// Must exactly match pubspec.yaml:
const String kQuranFontFamily = 'KFGQPC';

class FontTestPage extends StatelessWidget {
  const FontTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF3F8F3),
      body: Center(
        child: Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kQuranFontFamily,
            fontSize: 40,
            letterSpacing: 4,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}