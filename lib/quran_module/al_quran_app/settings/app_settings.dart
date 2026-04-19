enum TranslationLang {
  ms, // Malay
  en, // English
}

class AppSettings {
  final TranslationLang translation;
  final double arabicFontSize;

  const AppSettings({
    required this.translation,
    required this.arabicFontSize,
  });

  AppSettings copyWith({
    TranslationLang? translation,
    double? arabicFontSize,
  }) {
    return AppSettings(
      translation: translation ?? this.translation,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
    );
  }

  static const defaults = AppSettings(
    translation: TranslationLang.ms,
    arabicFontSize: 34,
  );
}