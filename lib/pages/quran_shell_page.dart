import 'package:flutter/material.dart';

/// Temporary shell for the Quran feature.
///
/// Your previous implementation imported `../quran_module/quran_entry.dart` and
/// returned `QuranEntry()`, but that file/class currently does not exist in the
/// project, which breaks compilation on both Android and iOS.
///
/// Once we fix the Quran module files, we can replace the body below to point to
/// the correct entry widget.
class QuranShellPage extends StatelessWidget {
  const QuranShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Quran'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Quran module is being repaired.\n\nNext: we will fix quran_surah_page.dart and quran_module.dart.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
