// lib/mushaf_page_view.dart
import 'package:flutter/material.dart';
import 'quran_api.dart';
import 'tajweed_text.dart';

class MushafPageView extends StatefulWidget {
  const MushafPageView({super.key});

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  // Mushaf has 604 pages, numbered 1..604
  static const int totalPages = 604;

  // Simple in-memory cache so we don’t refetch pages repeatedly
  final Map<int, List<QuranVerse>> _pageCache = {};

  Future<List<QuranVerse>> _loadPage(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber]!;
    }
    final verses = await QuranApi.fetchPage(pageNumber);
    final classes = <String>{};
    for (final v in verses) {
      final matches = RegExp(r'<tajweed class="?([\w_]+)"?>')
          .allMatches(v.text);
      for (final m in matches) {
        classes.add(m.group(1)!);
      }
    }
    _pageCache[pageNumber] = verses;
    return verses;
  }

  @override
  Widget build(BuildContext context) {
    // PageView index is 0-based, Mushaf pages are 1-based
    return PageView.builder(
      reverse: true, // swipe like real Mushaf (right-to-left)
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

            return Scaffold(
              backgroundColor: const Color(0xFFF9F7FF),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top bar with page number
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

                      // Actual ayat content, scrollable if long
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final verse in verses) ...[
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TajweedText(
                                    text: verse.text,
                                    fontSize: 32,
                                    baseColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}