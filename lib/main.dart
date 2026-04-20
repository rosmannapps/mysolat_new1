import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/waktu_solat_page.dart';
import 'pages/zikir_page.dart';
import 'pages/doa_categories_page.dart';
import 'pages/tetapan_page.dart';
import 'theme/app_theme.dart';
import 'services/prefs_service.dart';
import 'quran_module/al_quran_app/main.dart' as aq;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ms_MY', null);
  await PrefsService.init();
  runApp(const MySolatApp());
}

class MySolatApp extends StatelessWidget {
  const MySolatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySolat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = <Widget>[
    const WaktuSolatPage(),
    const ZikirPage(),
    const aq.QuranHomePage(),
    const DoaCategoriesPage(),
    const TetapanPage(),
  ];

  static const String _kWhatsNewShown = 'whats_new_v107_shown';
  static const Color _primary = Color(0xFF1F5E3E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWhatsNewIfNeeded();
    });
  }

  Future<void> _showWhatsNewIfNeeded() async {
    final shown = PrefsService.instance.getBool(_kWhatsNewShown) ?? false;
    if (shown || !mounted) return;
    await PrefsService.instance.setBool(_kWhatsNewShown, true);
    if (!mounted) return;
    _showWhatsNewDialog();
  }

  void _showWhatsNewDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.new_releases_rounded,
                  color: _primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                '✨ Ciri Baru MySolat!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 16),

              // Features list
              _WhatsNewItem(
                icon: Icons.mosque_rounded,
                title: 'Bunyi Azan',
                desc: 'MySolat kini memainkan bunyi Azan apabila masuk waktu solat.',
              ),
              const SizedBox(height: 10),
              _WhatsNewItem(
                icon: Icons.tune_rounded,
                title: 'Pilihan Bunyi',
                desc: 'Pilih antara Azan, Beep, Beep+Azan atau senyap sahaja.',
              ),
              const SizedBox(height: 10),
              _WhatsNewItem(
                icon: Icons.explore_rounded,
                title: 'Qibla Tepat',
                desc: 'Arah Qibla kini dikira berdasarkan lokasi GPS anda.',
              ),
              const SizedBox(height: 10),
              _WhatsNewItem(
                icon: Icons.location_on_rounded,
                title: 'Cari Zon Solat',
                desc: 'Butang lokasi yang lebih mudah dan jelas.',
              ),

              const SizedBox(height: 8),
              // Settings tip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _primary.withOpacity(0.7), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tukar tetapan bunyi di:\nTetapan → Notifikasi → Jenis Bunyi',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // OK button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Terima Kasih! 🙏',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _primary,
        unselectedItemColor: const Color(0xFF8FA89A),
        selectedFontSize: 12,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.white,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque_outlined),
            activeIcon: Icon(Icons.mosque_rounded),
            label: 'Solat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.back_hand_outlined),
            activeIcon: Icon(Icons.back_hand_rounded),
            label: 'Zikir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book_rounded),
            label: 'Quran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined),
            activeIcon: Icon(Icons.volunteer_activism_rounded),
            label: 'Doa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Tetapan',
          ),
        ],
      ),
    );
  }
}

class _WhatsNewItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _WhatsNewItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  static const Color _primary = Color(0xFF1F5E3E);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: _primary.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
