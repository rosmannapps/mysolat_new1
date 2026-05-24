// lib/tajwid/tajweed_colors.dart
import 'package:flutter/material.dart';

class TajweedColors {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color hamWasl          = Color(0xFF9AA0A6); // grey
  static const Color laamShamsiyah    = Color(0xFF9AA0A6); // grey
  static const Color silent           = Color(0xFF9AA0A6); // grey

  static const Color maddaNormal      = Color(0xFF537FFF); // blue
  static const Color maddaPermissible = Color(0xFF4050FF); // deeper blue
  static const Color maddaNecessary   = Color(0xFF000EBC); // navy
  static const Color maddaObligatory  = Color(0xFF2144C1); // dark blue

  static const Color qalqalah         = Color(0xFFDD0008); // red

  static const Color ikhfaShafawi     = Color(0xFFD500B7); // pink/magenta
  static const Color ikhfa            = Color(0xFF9400A8); // purple

  static const Color idghamShafawi    = Color(0xFF58B800); // green
  static const Color iqlab            = Color(0xFF26BFFD); // light blue
  static const Color idghamGhunnah    = Color(0xFF169777); // teal
  static const Color idghamWoGhunnah  = Color(0xFF169200); // dark green
  static const Color idghamMutajanisain = Color(0xFFA1A1A1); // silver

  static const Color ghunnah         = Color(0xFFFF7E1E); // orange

  static const Color verseEnd        = Color(0xFF9E9E9E); // grey

  // ── Lookup ───────────────────────────────────────────────────────────────
  /// Handles BOTH Quran.com short-form keys (e.g. 'qlq', 'ghn', 'ikhf')
  /// AND the long-form keys used in some datasets (e.g. 'qalaqah', 'ghunnah').
  static Color? colorFor(String rule) {
    switch (rule) {
    // ── Hamzah / Laam ──────────────────────────────────────────
      case 'ham_wasl':
        return hamWasl;
      case 'laam_shamsiyah':
        return laamShamsiyah;
      case 'slnt':
      case 'silent':
        return silent;

    // ── Madd ───────────────────────────────────────────────────
      case 'madda_normal':
      case 'mdd_nrm':
        return maddaNormal;
      case 'madda_permissible':
      case 'mdd_prm':
        return maddaPermissible;
      case 'madda_necessary':
      case 'mdd_ncs':
        return maddaNecessary;
      case 'madda_obligatory':
      case 'madda_o':
      case 'mdd_obl':
        return maddaObligatory;

    // ── Qalqalah ───────────────────────────────────────────────
      case 'qlq':
      case 'qalaqah':
      case 'qalqalah':
        return qalqalah;

    // ── Ikhfa ──────────────────────────────────────────────────
      case 'ikhf_shfw':
      case 'ikhfa_shafawi':
        return ikhfaShafawi;
      case 'ikhf':
      case 'ikhfa':
        return ikhfa;

    // ── Idgham / Iqlab ─────────────────────────────────────────
      case 'idghm_shfw':
      case 'idgham_shafawi':
        return idghamShafawi;
      case 'iqlb':
      case 'iqlab':
        return iqlab;
      case 'idgh_ghn':
      case 'idgham_ghunnah':
      case 'idgham_w_ghunnah':
        return idghamGhunnah;
      case 'idgh_w_ghn':
      case 'idgham_wo_ghunnah':
      case 'idgham_without_ghunnah':
        return idghamWoGhunnah;
      case 'idgh_mus':
      case 'idgham_mutajanisain':
      case 'idgham_mutaqaribain':
        return idghamMutajanisain;

    // ── Ghunnah ────────────────────────────────────────────────
      case 'ghn':
      case 'ghunnah':
        return ghunnah;

    // ── Verse end marker ───────────────────────────────────────
      case 'end':
        return verseEnd;

      default:
        return null; // falls back to normalColor in the renderer
    }
  }
}