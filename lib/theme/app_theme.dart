// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ---------------- BRAND (from your current file) ----------------
  static const Color bg = Color(0xFFF1F7F2);
  static const Color card = Colors.white;

  static const Color primary = Color(0xFF0F4D32);
  static const Color primarySoft = Color(0xFFE7F3EA);

  static const Color text = Color(0xFF25483C);
  static const Color subtitle = Color(0xFF55766A);

  static const Color accent = Color(0xFF5A7E6D);

  // Optional “gold” accent that matches your icon (use for highlights)
  static const Color gold = Color(0xFFD6B35B);

  // ---------------- DARK PALETTE (exclusive, not pure black) ----------------
  static const Color bgDark = Color(0xFF0B1510);
  static const Color cardDark = Color(0xFF0F1E16);
  static const Color primaryDark = Color(0xFF54B084); // minty emerald for dark UI
  static const Color accentDark = Color(0xFF9CCDB6);
  static const Color textDark = Color(0xFFEAF6EE);
  static const Color subtitleDark = Color(0xFF9AB7A7);

  // ---------------- PUBLIC THEMES ----------------

  /// Keep your original name so you don't break imports
  static ThemeData iosMint() => light();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: card,
        background: bg,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        foregroundColor: primary,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
      textTheme: _textTheme(base.textTheme, isDark: false),
      listTileTheme: const ListTileThemeData(
        tileColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          color: subtitle,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: _roundedBorder(),
        focusedBorder: _roundedBorder(),
        border: _roundedBorder(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF3F1F7),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9CB3A8),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: primarySoft,
        labelStyle: TextStyle(color: primary, fontWeight: FontWeight.w700),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        secondary: accentDark,
        surface: cardDark,
        background: bgDark,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textDark,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
      textTheme: _textTheme(base.textTheme, isDark: true),
      listTileTheme: const ListTileThemeData(
        tileColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          color: subtitleDark,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        hintStyle: const TextStyle(color: subtitleDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: _roundedBorderDark(),
        focusedBorder: _roundedBorderDark(),
        border: _roundedBorderDark(),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0C1912),
        selectedItemColor: primaryDark,
        unselectedItemColor: Color(0xFF6C887B),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF173125),
        labelStyle: TextStyle(color: textDark, fontWeight: FontWeight.w700),
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF10271B),
        contentTextStyle: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // ---------------- HELPERS for pages (optional but very useful) ----------------
  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

  static Color bgOf(BuildContext c) => isDark(c) ? bgDark : bg;
  static Color cardOf(BuildContext c) => isDark(c) ? cardDark : card;
  static Color textOf(BuildContext c) => isDark(c) ? textDark : text;
  static Color subtitleOf(BuildContext c) => isDark(c) ? subtitleDark : subtitle;
  static Color primaryOf(BuildContext c) => isDark(c) ? primaryDark : primary;
  static Color accentOf(BuildContext c) => isDark(c) ? accentDark : accent;

  // ---------------- INTERNALS ----------------
  static OutlineInputBorder _roundedBorder() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );

  static OutlineInputBorder _roundedBorderDark() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
  );

  static TextTheme _textTheme(TextTheme base, {required bool isDark}) {
    final Color h = isDark ? textDark : primary;
    final Color b1 = isDark ? textDark : text;
    final Color b2 = isDark ? subtitleDark : subtitle;

    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: h,
        fontWeight: FontWeight.w800,
        fontSize: 34,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: h,
        fontWeight: FontWeight.w800,
        fontSize: 28,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: h,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: b1,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: b2,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}