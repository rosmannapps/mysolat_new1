// lib/quran_page.dart
import 'package:flutter/material.dart';
import '../quran_api.dart';
import '../tajweed_text.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  static const int totalPages = 604;
  final Map<int, List<QuranVerse>> _pageCache = {};

  Future<List<QuranVerse>> _loadPage(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber]!;
    }
    final verses = await QuranApi.fetchPage(pageNumber);
    _pageCache[pageNumber] = verses;
    return verses;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PageView.builder(
        reverse: true, // swipe right-to-left
        itemCount: totalPages,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;

          return FutureBuilder<List<QuranVerse>>(
            future: _loadPage(pageNumber),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading page $pageNumber:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final verses = snapshot.data ?? [];

              return Container(
                color: const Color(0xFFF9F7FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page $pageNumber / $totalPages',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final verse in verses) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TajweedText(text: verse.text),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}