
import 'package:flutter/material.dart';
import 'bookmark_page.dart';
import '../services/bookmark_storage.dart';
import 'quran_module_entry.dart';

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  final TextEditingController _searchController = TextEditingController();

  List<SurahMeta> _filtered = _allSurahMeta;

  Set<int> _bookmarkedSurahs = {};
  int _bookmarkCount = 0;

  // iOS-like palette
  static const Color _bg = Color(0xFFEFFAF2); // mint lembut
  static const Color _ink = Color(0xFF0B6B3A); // hijau tua kemas
  static const Color _card = Color(0xFFF7FBF7); // card lembut
  static const Color _stroke = Color(0xFFD7EBDD);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadBookmarkedSurahs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- SEARCH ----------------

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _filtered = _allSurahMeta;
      } else {
        _filtered = _allSurahMeta.where((s) {
          final latin = s.nameLatin.toLowerCase();
          final number = s.number.toString();
          final arabic = s.nameArabic;
          return latin.contains(q) || arabic.contains(q) || number == q;
        }).toList();
      }
    });
  }

  // ---------------- BOOKMARK STATE ----------------

  Future<void> _loadBookmarkedSurahs() async {
    final list = await BookmarkStorage.loadBookmarks();
    if (!mounted) return;

    setState(() {
      _bookmarkedSurahs = list.map((b) => b.surahNumber).toSet();
      _bookmarkCount = list.length;
    });
  }

  Future<void> _openBookmarkPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BookmarkPage()),
    );
    await _loadBookmarkedSurahs();
  }

  // ---------------- UI HELPERS ----------------

  Widget _circleIconButton({
    required Widget child,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Center(child: child)),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search, color: _ink.withOpacity(0.55)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Cari surah / السورة',
                hintStyle: TextStyle(
                  color: _ink.withOpacity(0.45),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Padam',
              onPressed: () {
                _searchController.clear();
                _onSearchChanged();
              },
              icon: Icon(Icons.close, color: _ink.withOpacity(0.6)),
            ),
        ],
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // Header row: title + bookmark circle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Al-Qur'an",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.0,
                      ),
                    ),
                  ),
                  // Bookmark button (white circle) + badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _circleIconButton(
                        tooltip: 'Penanda',
                        onTap: _openBookmarkPage,
                        child: Icon(
                          Icons.bookmark_outline,
                          color: _ink,
                          size: 26,
                        ),
                      ),
                      if (_bookmarkCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              _bookmarkCount > 9 ? '9+' : _bookmarkCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _searchBar(),
            ),

            const SizedBox(height: 12),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final s = _filtered[index];
                  final hasBookmark = _bookmarkedSurahs.contains(s.number);

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QuranModuleEntryPage(),
                        ),
                      );

                      await _loadBookmarkedSurahs();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _stroke),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // number circle
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _stroke),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              s.number.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _ink,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Latin + ayat count
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.nameLatin,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${s.ayahCount} ayat',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Arabic name (KFGQPC)
                          Text(
                            s.nameArabic,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 21,
                              color: _ink,
                              fontFamily: 'KFGQPC',
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Bookmark dot
                          if (hasBookmark)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),

                          const SizedBox(width: 6),

                          Icon(
                            Icons.chevron_right,
                            color: _ink.withOpacity(0.45),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SurahMeta {
  final int number;
  final String nameArabic;
  final String nameLatin;
  final int ayahCount;

  const SurahMeta({
    required this.number,
    required this.nameArabic,
    required this.nameLatin,
    required this.ayahCount,
  });
}

const List<SurahMeta> _allSurahMeta = [
  SurahMeta(number: 1, nameArabic: 'الفاتحة', nameLatin: 'Al-Fātiḥah', ayahCount: 7),
  SurahMeta(number: 2, nameArabic: 'البقرة', nameLatin: 'Al-Baqarah', ayahCount: 286),
  SurahMeta(number: 3, nameArabic: 'آل عمران', nameLatin: 'Āl ʿImrān', ayahCount: 200),
  SurahMeta(number: 4, nameArabic: 'النساء', nameLatin: 'An-Nisā’', ayahCount: 176),
  SurahMeta(number: 5, nameArabic: 'المائدة', nameLatin: 'Al-Mā’idah', ayahCount: 120),
  SurahMeta(number: 6, nameArabic: 'الأنعام', nameLatin: 'Al-Anʿām', ayahCount: 165),
  SurahMeta(number: 7, nameArabic: 'الأعراف', nameLatin: 'Al-Aʿrāf', ayahCount: 206),
  SurahMeta(number: 8, nameArabic: 'الأنفال', nameLatin: 'Al-Anfāl', ayahCount: 75),
  SurahMeta(number: 9, nameArabic: 'التوبة', nameLatin: 'At-Tawbah', ayahCount: 129),
  SurahMeta(number: 10, nameArabic: 'يونس', nameLatin: 'Yūnus', ayahCount: 109),
  SurahMeta(number: 11, nameArabic: 'هود', nameLatin: 'Hūd', ayahCount: 123),
  SurahMeta(number: 12, nameArabic: 'يوسف', nameLatin: 'Yūsuf', ayahCount: 111),
  SurahMeta(number: 13, nameArabic: 'الرعد', nameLatin: 'Ar-Raʿd', ayahCount: 43),
  SurahMeta(number: 14, nameArabic: 'إبراهيم', nameLatin: 'Ibrāhīm', ayahCount: 52),
  SurahMeta(number: 15, nameArabic: 'الحجر', nameLatin: 'Al-Ḥijr', ayahCount: 99),
  SurahMeta(number: 16, nameArabic: 'النحل', nameLatin: 'An-Naḥl', ayahCount: 128),
  SurahMeta(number: 17, nameArabic: 'الإسراء', nameLatin: 'Al-Isrā’', ayahCount: 111),
  SurahMeta(number: 18, nameArabic: 'الكهف', nameLatin: 'Al-Kahf', ayahCount: 110),
  SurahMeta(number: 19, nameArabic: 'مريم', nameLatin: 'Maryam', ayahCount: 98),
  SurahMeta(number: 20, nameArabic: 'طه', nameLatin: 'Ṭā Hā', ayahCount: 135),
  SurahMeta(number: 21, nameArabic: 'الأنبياء', nameLatin: 'Al-Anbiyā’', ayahCount: 112),
  SurahMeta(number: 22, nameArabic: 'الحج', nameLatin: 'Al-Ḥajj', ayahCount: 78),
  SurahMeta(number: 23, nameArabic: 'المؤمنون', nameLatin: 'Al-Mu’minūn', ayahCount: 118),
  SurahMeta(number: 24, nameArabic: 'النور', nameLatin: 'An-Nūr', ayahCount: 64),
  SurahMeta(number: 25, nameArabic: 'الفرقان', nameLatin: 'Al-Furqān', ayahCount: 77),
  SurahMeta(number: 26, nameArabic: 'الشعراء', nameLatin: 'Ash-Shuʿarā’', ayahCount: 227),
  SurahMeta(number: 27, nameArabic: 'النمل', nameLatin: 'An-Naml', ayahCount: 93),
  SurahMeta(number: 28, nameArabic: 'القصص', nameLatin: 'Al-Qaṣaṣ', ayahCount: 88),
  SurahMeta(number: 29, nameArabic: 'العنكبوت', nameLatin: 'Al-ʿAnkabūt', ayahCount: 69),
  SurahMeta(number: 30, nameArabic: 'الروم', nameLatin: 'Ar-Rūm', ayahCount: 60),
  SurahMeta(number: 31, nameArabic: 'لقمان', nameLatin: 'Luqmān', ayahCount: 34),
  SurahMeta(number: 32, nameArabic: 'السجدة', nameLatin: 'As-Sajdah', ayahCount: 30),
  SurahMeta(number: 33, nameArabic: 'الأحزاب', nameLatin: 'Al-Aḥzāb', ayahCount: 73),
  SurahMeta(number: 34, nameArabic: 'سبإ', nameLatin: 'Saba’', ayahCount: 54),
  SurahMeta(number: 35, nameArabic: 'فاطر', nameLatin: 'Fāṭir', ayahCount: 45),
  SurahMeta(number: 36, nameArabic: 'يس', nameLatin: 'Yā Sīn', ayahCount: 83),
  SurahMeta(number: 37, nameArabic: 'الصافات', nameLatin: 'Aṣ-Ṣāffāt', ayahCount: 182),
  SurahMeta(number: 38, nameArabic: 'ص', nameLatin: 'Ṣād', ayahCount: 88),
  SurahMeta(number: 39, nameArabic: 'الزمر', nameLatin: 'Az-Zumar', ayahCount: 75),
  SurahMeta(number: 40, nameArabic: 'غافر', nameLatin: 'Ghāfir', ayahCount: 85),
  SurahMeta(number: 41, nameArabic: 'فصلت', nameLatin: 'Fuṣṣilat', ayahCount: 54),
  SurahMeta(number: 42, nameArabic: 'الشورى', nameLatin: 'Ash-Shūrā', ayahCount: 53),
  SurahMeta(number: 43, nameArabic: 'الزخرف', nameLatin: 'Az-Zukhruf', ayahCount: 89),
  SurahMeta(number: 44, nameArabic: 'الدخان', nameLatin: 'Ad-Dukhān', ayahCount: 59),
  SurahMeta(number: 45, nameArabic: 'الجاثية', nameLatin: 'Al-Jāthiyah', ayahCount: 37),
  SurahMeta(number: 46, nameArabic: 'الأحقاف', nameLatin: 'Al-Aḥqāf', ayahCount: 35),
  SurahMeta(number: 47, nameArabic: 'محمد', nameLatin: 'Muḥammad', ayahCount: 38),
  SurahMeta(number: 48, nameArabic: 'الفتح', nameLatin: 'Al-Fatḥ', ayahCount: 29),
  SurahMeta(number: 49, nameArabic: 'الحجرات', nameLatin: 'Al-Ḥujurāt', ayahCount: 18),
  SurahMeta(number: 50, nameArabic: 'ق', nameLatin: 'Qāf', ayahCount: 45),
  SurahMeta(number: 51, nameArabic: 'الذاريات', nameLatin: 'Adh-Dhāriyāt', ayahCount: 60),
  SurahMeta(number: 52, nameArabic: 'الطور', nameLatin: 'Aṭ-Ṭūr', ayahCount: 49),
  SurahMeta(number: 53, nameArabic: 'النجم', nameLatin: 'An-Najm', ayahCount: 62),
  SurahMeta(number: 54, nameArabic: 'القمر', nameLatin: 'Al-Qamar', ayahCount: 55),
  SurahMeta(number: 55, nameArabic: 'الرحمن', nameLatin: 'Ar-Raḥmān', ayahCount: 78),
  SurahMeta(number: 56, nameArabic: 'الواقعة', nameLatin: 'Al-Wāqiʿah', ayahCount: 96),
  SurahMeta(number: 57, nameArabic: 'الحديد', nameLatin: 'Al-Ḥadīd', ayahCount: 29),
  SurahMeta(number: 58, nameArabic: 'المجادلة', nameLatin: 'Al-Mujādilah', ayahCount: 22),
  SurahMeta(number: 59, nameArabic: 'الحشر', nameLatin: 'Al-Ḥashr', ayahCount: 24),
  SurahMeta(number: 60, nameArabic: 'الممتحنة', nameLatin: 'Al-Mumtaḥanah', ayahCount: 13),
  SurahMeta(number: 61, nameArabic: 'الصف', nameLatin: 'Aṣ-Ṣaff', ayahCount: 14),
  SurahMeta(number: 62, nameArabic: 'الجمعة', nameLatin: 'Al-Jumuʿah', ayahCount: 11),
  SurahMeta(number: 63, nameArabic: 'المنافقون', nameLatin: 'Al-Munāfiqūn', ayahCount: 11),
  SurahMeta(number: 64, nameArabic: 'التغابن', nameLatin: 'At-Taghābun', ayahCount: 18),
  SurahMeta(number: 65, nameArabic: 'الطلاق', nameLatin: 'Aṭ-Ṭalāq', ayahCount: 12),
  SurahMeta(number: 66, nameArabic: 'التحريم', nameLatin: 'At-Taḥrīm', ayahCount: 12),
  SurahMeta(number: 67, nameArabic: 'الملك', nameLatin: 'Al-Mulk', ayahCount: 30),
  SurahMeta(number: 68, nameArabic: 'القلم', nameLatin: 'Al-Qalam', ayahCount: 52),
  SurahMeta(number: 69, nameArabic: 'الحاقة', nameLatin: 'Al-Ḥāqqah', ayahCount: 52),
  SurahMeta(number: 70, nameArabic: 'المعارج', nameLatin: 'Al-Maʿārij', ayahCount: 44),
  SurahMeta(number: 71, nameArabic: 'نوح', nameLatin: 'Nūḥ', ayahCount: 28),
  SurahMeta(number: 72, nameArabic: 'الجن', nameLatin: 'Al-Jinn', ayahCount: 28),
  SurahMeta(number: 73, nameArabic: 'المزمل', nameLatin: 'Al-Muzzammil', ayahCount: 20),
  SurahMeta(number: 74, nameArabic: 'المدثر', nameLatin: 'Al-Muddaththir', ayahCount: 56),
  SurahMeta(number: 75, nameArabic: 'القيامة', nameLatin: 'Al-Qiyāmah', ayahCount: 40),
  SurahMeta(number: 76, nameArabic: 'الإنسان', nameLatin: 'Al-Insān', ayahCount: 31),
  SurahMeta(number: 77, nameArabic: 'المرسلات', nameLatin: 'Al-Mursalāt', ayahCount: 50),
  SurahMeta(number: 78, nameArabic: 'النبإ', nameLatin: 'An-Naba’', ayahCount: 40),
  SurahMeta(number: 79, nameArabic: 'النازعات', nameLatin: 'An-Nāziʿāt', ayahCount: 46),
  SurahMeta(number: 80, nameArabic: 'عبس', nameLatin: 'ʿAbasa', ayahCount: 42),
  SurahMeta(number: 81, nameArabic: 'التكوير', nameLatin: 'At-Takwīr', ayahCount: 29),
  SurahMeta(number: 82, nameArabic: 'الانفطار', nameLatin: 'Al-Infiṭār', ayahCount: 19),
  SurahMeta(number: 83, nameArabic: 'المطففين', nameLatin: 'Al-Muṭaffifīn', ayahCount: 36),
  SurahMeta(number: 84, nameArabic: 'الانشقاق', nameLatin: 'Al-Inshiqāq', ayahCount: 25),
  SurahMeta(number: 85, nameArabic: 'البروج', nameLatin: 'Al-Burūj', ayahCount: 22),
  SurahMeta(number: 86, nameArabic: 'الطارق', nameLatin: 'Aṭ-Ṭāriq', ayahCount: 17),
  SurahMeta(number: 87, nameArabic: 'الأعلى', nameLatin: 'Al-Aʿlā', ayahCount: 19),
  SurahMeta(number: 88, nameArabic: 'الغاشية', nameLatin: 'Al-Ghāshiyah', ayahCount: 26),
  SurahMeta(number: 89, nameArabic: 'الفجر', nameLatin: 'Al-Fajr', ayahCount: 30),
  SurahMeta(number: 90, nameArabic: 'البلد', nameLatin: 'Al-Balad', ayahCount: 20),
  SurahMeta(number: 91, nameArabic: 'الشمس', nameLatin: 'Ash-Shams', ayahCount: 15),
  SurahMeta(number: 92, nameArabic: 'الليل', nameLatin: 'Al-Layl', ayahCount: 21),
  SurahMeta(number: 93, nameArabic: 'الضحى', nameLatin: 'Aḍ-Ḍuḥā', ayahCount: 11),
  SurahMeta(number: 94, nameArabic: 'الشرح', nameLatin: 'Ash-Sharḥ', ayahCount: 8),
  SurahMeta(number: 95, nameArabic: 'التين', nameLatin: 'At-Tīn', ayahCount: 8),
  SurahMeta(number: 96, nameArabic: 'العلق', nameLatin: 'Al-ʿAlaq', ayahCount: 19),
  SurahMeta(number: 97, nameArabic: 'القدر', nameLatin: 'Al-Qadr', ayahCount: 5),
  SurahMeta(number: 98, nameArabic: 'البينة', nameLatin: 'Al-Bayyinah', ayahCount: 8),
  SurahMeta(number: 99, nameArabic: 'الزلزلة', nameLatin: 'Az-Zalzalah', ayahCount: 8),
  SurahMeta(number: 100, nameArabic: 'العاديات', nameLatin: 'Al-ʿĀdiyāt', ayahCount: 11),
  SurahMeta(number: 101, nameArabic: 'القارعة', nameLatin: 'Al-Qāriʿah', ayahCount: 11),
  SurahMeta(number: 102, nameArabic: 'التكاثر', nameLatin: 'At-Takāthur', ayahCount: 8),
  SurahMeta(number: 103, nameArabic: 'العصر', nameLatin: 'Al-ʿAṣr', ayahCount: 3),
  SurahMeta(number: 104, nameArabic: 'الهمزة', nameLatin: 'Al-Humazah', ayahCount: 9),
  SurahMeta(number: 105, nameArabic: 'الفيل', nameLatin: 'Al-Fīl', ayahCount: 5),
  SurahMeta(number: 106, nameArabic: 'قريش', nameLatin: 'Quraysh', ayahCount: 4),
  SurahMeta(number: 107, nameArabic: 'الماعون', nameLatin: 'Al-Māʿūn', ayahCount: 7),
  SurahMeta(number: 108, nameArabic: 'الكوثر', nameLatin: 'Al-Kawthar', ayahCount: 3),
  SurahMeta(number: 109, nameArabic: 'الكافرون', nameLatin: 'Al-Kāfirūn', ayahCount: 6),
  SurahMeta(number: 110, nameArabic: 'النصر', nameLatin: 'An-Naṣr', ayahCount: 3),
  SurahMeta(number: 111, nameArabic: 'المسد', nameLatin: 'Al-Masad', ayahCount: 5),
  SurahMeta(number: 112, nameArabic: 'الإخلاص', nameLatin: 'Al-Ikhlāṣ', ayahCount: 4),
  SurahMeta(number: 113, nameArabic: 'الفلق', nameLatin: 'Al-Falaq', ayahCount: 5),
  SurahMeta(number: 114, nameArabic: 'الناس', nameLatin: 'An-Nās', ayahCount: 6),
];