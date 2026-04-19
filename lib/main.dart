import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/waktu_solat_page.dart';
import 'pages/zikir_page.dart';
import 'pages/doa_categories_page.dart';
import 'pages/tetapan_page.dart';
import 'theme/app_theme.dart';
import 'services/prefs_service.dart';

// ✅ Use the Al-Quran module page (gold UI)
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
        selectedItemColor: const Color(0xFF1F5E3E),
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
