import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/prefs_service.dart';

// ✅ NEW: timezone init for scheduled (zoned) notifications
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'pages/waktu_solat_page.dart';
import 'pages/zikir_page.dart';
import 'pages/doa_categories_page.dart';
import 'pages/tetapan_page.dart';
import 'services/prayer_times_service.dart';
import 'theme/app_theme.dart';

// ✅ Use the Al-Quran module page (gold UI)
import 'quran_module/al_quran_app/main.dart' as aq;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ REQUIRED for Quran/settings/preferences
  await PrefsService.init();

  await initializeDateFormatting('ms_MY', null);

  // ─── Timezone initialisation ───
  tzdata.initializeTimeZones();

  try {
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
  } catch (_) {
    // fallback
  }

  // ─── Cache hygiene (fire-and-forget) ───
  // Removes prayer-time cache entries older than 60 days so SharedPreferences
  // doesn't grow unboundedly. Runs in background — does not block startup.
  // ignore: unawaited_futures
  Future(() async {
    try {
      final svc = PrayerTimesService();
      await svc.purgeOldCache();
      svc.dispose();
    } catch (_) {}
  });

  runApp(const MySolatApp());
}

class MySolatApp extends StatelessWidget {
  const MySolatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySolat',
      debugShowCheckedModeBanner: false,

      // ✅ Gold theme everywhere (this also fixes blue sliders/buttons)
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

  // ✅ Use aq.QuranHomePage (gold module)
  final List<Widget> _pages = <Widget>[
    const WaktuSolatPage(),
    const ZikirPage(),
    const aq.QuranHomePage(),
    const DoaCategoriesPage(),
    const TetapanPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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

        // ✅ Gold selected color (no more purple)
        selectedItemColor: scheme.primary, // = gold from seed
        unselectedItemColor: Colors.grey.shade600,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_rounded),
            label: 'Solat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.back_hand_rounded),
            label: 'Zikir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Quran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_rounded),
            label: 'Doa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Tetapan',
          ),
        ],
      ),
    );
  }
}