import 'package:flutter/material.dart';

/// Shared iOS-like Aa text settings sheet used across Quran / Zikir / Doa.
///
/// - Shows live numbers (Arabik XX, Melayu XX)
/// - +/- steppers (numbers AND actual font sizes update via callbacks)
/// - Optional translation toggle (for Doa/Zikir). Quran can hide it.
class AaTextSettingsSheet extends StatelessWidget {
  final int arabicValue;
  final int malayValue;

  final VoidCallback onArabicMinus;
  final VoidCallback onArabicPlus;
  final VoidCallback onMalayMinus;
  final VoidCallback onMalayPlus;

  // Optional translation toggle (use in Doa/Zikir; hide for Quran if you want)
  final bool showTranslationToggle;
  final bool showTranslation;
  final ValueChanged<bool> onToggleTranslation;

  // Optional labels
  final String arabicLabel;
  final String malayLabel;

  // Optional appearance controls (useful for floating/transparent UI)
  final double backgroundOpacity; // 0.0 - 1.0
  final EdgeInsets margin;

  // NEW: allow disabling SafeArea for floating overlays
  final bool useSafeArea;

  const AaTextSettingsSheet({
    super.key,
    required this.arabicValue,
    required this.malayValue,
    required this.onArabicMinus,
    required this.onArabicPlus,
    required this.onMalayMinus,
    required this.onMalayPlus,
    this.showTranslationToggle = true,
    this.showTranslation = true,
    required this.onToggleTranslation,
    this.arabicLabel = 'Arabik',
    this.malayLabel = 'Melayu',
    this.backgroundOpacity = 0.95,
    this.margin = const EdgeInsets.fromLTRB(14, 0, 14, 14),
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        // If backgroundOpacity=0, this becomes fully transparent (for glass overlays)
        color: const Color(0xFFE6E8EC).withOpacity(backgroundOpacity),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 2,
            offset: Offset(0, 10),
            color: Color(0x33000000),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rowStepper(
            label: arabicLabel,
            value: arabicValue,
            onMinus: onArabicMinus,
            onPlus: onArabicPlus,
          ),
          const SizedBox(height: 12),
          _rowStepper(
            label: malayLabel,
            value: malayValue,
            onMinus: onMalayMinus,
            onPlus: onMalayPlus,
          ),
          if (showTranslationToggle) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tunjuk Terjemahan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: showTranslation,
                  onChanged: onToggleTranslation,
                  activeColor: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!useSafeArea) return sheet;
    return SafeArea(child: sheet);
  }

  static Widget _rowStepper({
    required String label,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label $value',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        _roundIconButton(icon: Icons.remove, onTap: onMinus),
        const SizedBox(width: 10),
        _roundIconButton(icon: Icons.add, onTap: onPlus),
      ],
    );
  }

  static Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFF3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x22000000)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: const Color(0xFF1E57D8)),
      ),
    );
  }
}