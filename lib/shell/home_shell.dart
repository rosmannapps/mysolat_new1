// lib/shell/home_shell.dart
import 'package:flutter/material.dart';

import '../pages/waktu_solat_page.dart';
import '../pages/zikir_page.dart';
import '../pages/quran_page.dart';
import '../pages/doa_page.dart';
import '../pages/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  // iOS-like mint theme (based on your screenshot)
  static const Color _screenBg = Color(0xFFE8F6EE); // mint background
  static const Color _pillBg = Colors.white;
  static const Color _pillBorder = Color(0xFFE6E6E6);
  static const Color _bubble = Color(0xFFE7E7E7); // selected rounded bubble
  static const Color _selectedGreen = Color(0xFF0A6B3E); // deep green
  static const Color _unselected = Color(0xFF111111);

  late final List<Widget> _pages = <Widget>[
    const WaktuSolatPage(),
    const ZikirPage(),
    const QuranPage(),
    const DoaPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: _IosPillTabBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: _pillBg,
            borderColor: _pillBorder,
            selectedBubbleColor: _bubble,
            selectedColor: _selectedGreen,
            unselectedColor: _unselected,
            items: const [
              _IosPillTabItem(label: 'Waktu', icon: Icons.access_time_rounded),
              _IosPillTabItem(label: 'Zikir', icon: Icons.front_hand_rounded),
              _IosPillTabItem(label: 'Quran', icon: Icons.menu_book_rounded),
              _IosPillTabItem(label: 'Doa', icon: Icons.book_rounded),
              _IosPillTabItem(label: 'Tetapan', icon: Icons.settings_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosPillTabItem {
  final String label;
  final IconData icon;
  const _IosPillTabItem({required this.label, required this.icon});
}

class _IosPillTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_IosPillTabItem> items;

  final Color backgroundColor;
  final Color borderColor;
  final Color selectedBubbleColor;
  final Color selectedColor;
  final Color unselectedColor;

  const _IosPillTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.backgroundColor,
    required this.borderColor,
    required this.selectedBubbleColor,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final bool isSmall = w < 360;

    return Container(
      height: isSmall ? 70 : 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == currentIndex;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                decoration: selected
                    ? BoxDecoration(
                  color: selectedBubbleColor,
                  borderRadius: BorderRadius.circular(999),
                )
                    : const BoxDecoration(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: isSmall ? 24 : 28,
                      color: selected ? selectedColor : unselectedColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? selectedColor : unselectedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}