// lib/pages/bookmark_page.dart
import 'package:flutter/material.dart';
import '../mushaf_page_view.dart';

import '../services/bookmark_storage.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  late Future<List<Bookmark>> _future;

  @override
  void initState() {
    super.initState();
    _future = BookmarkStorage.loadBookmarks();
  }

  Future<void> _refresh() async {
    final list = await BookmarkStorage.loadBookmarks();
    if (!mounted) return;
    setState(() {
      _future = Future.value(list);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sama seperti Quran Home
    const bg = Color(0xFFEFFBF2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Penanda',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 26,
          ),
        ),
      ),
      body: FutureBuilder<List<Bookmark>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookmarks = snap.data ?? [];

          // Tiada bookmark lagi
          if (bookmarks.isEmpty) {
            return const Center(
              child: Text(
                'Tiada penanda lagi.\n\n'
                    'Tekan dan tahan pada ayat untuk membuat penanda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: bookmarks.length + 1, // +1 utk instruction di atas
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                // 🔹 Instruction bar di atas list
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Text(
                        '➤ Tekan dan tahan pada ayat beberapa saat untuk membuat penanda. Swipe kiri untuk padam',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade800,
                          fontWeight : FontWeight .w800
                        ),
                      ),
                    ),
                  );
                }

                final b = bookmarks[index - 1];

                return Dismissible(
                  key: ValueKey('bm-${b.surahNumber}-${b.ayahNumber}'),
                  direction: DismissDirection.endToStart, // swipe kanan→kiri
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    // optional confirm dialog kalau nak
                    return true;
                  },
                  onDismissed: (_) async {
                    // Padam dari storage
                    await BookmarkStorage.remove(b);
                    // Reload future supaya UI update
                    if (mounted) {
                      setState(() {
                        _future = BookmarkStorage.loadBookmarks();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Penanda dipadam: ${b.surahLatin} ayat ${b.ayahNumber}',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MushafPageView(

                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${b.surahLatin} • Ayat ${b.ayahNumber}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Surah ${b.surahNumber} • Ayat ${b.ayahNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}