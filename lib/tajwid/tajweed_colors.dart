import 'package:flutter/material.dart';

class TajweedColors {
  // Default fallback colors (you can tune later)
  static const Color hamWasl = Color(0xFF2E7D32); // green
  static const Color laamShamsiyah = Color(0xFF1565C0); // blue
  static const Color maddaNormal = Color(0xFFD32F2F); // red
  static const Color maddaPermissible = Color(0xFF6A1B9A); // purple
  static const Color maddaNecessary = Color(0xFFF57C00); // orange
  static const Color idghamGhunnah = Color(0xFF00897B); // teal
  static const Color idghamWoGhunnah = Color(0xFF5D4037); // brown
  static const Color ikhafa = Color(0xFF546E7A); // blueGrey
  static const Color ghunnah = Color(0xFF00ACC1); // cyan
  static const Color qalqah = Color(0xFF7B1FA2); // deep purple
  static const Color slnt = Color(0xFF455A64); // dark blueGrey

  /// IMPORTANT: this is what your tajwid_rich_text.dart expects
  static Color? colorFor(String rule) {
    switch (rule) {
      case 'ham_wasl':
        return hamWasl;
      case 'laam_shamsiyah':
        return laamShamsiyah;

      case 'madda_normal':
        return maddaNormal;
      case 'madda_permissible':
        return maddaPermissible;
      case 'madda_necessary':
        return maddaNecessary;

      case 'idgham_ghunnah':
        return idghamGhunnah;
      case 'idgham_wo_ghunnah':
        return idghamWoGhunnah;

      case 'ikhafa':
        return ikhafa;
      case 'ghunnah':
        return ghunnah;
      case 'qalaqah':
        return qalqah;

      case 'slnt':
        return slnt;

      default:
        return null; // fallback to normalColor
    }
  }
}