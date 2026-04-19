class VerseTranslation {
  final String verseKey; // e.g. "1:1"
  final String text;

  VerseTranslation({
    required this.verseKey,
    required this.text,
  });

  factory VerseTranslation.fromJson(Map<String, dynamic> json) {
    return VerseTranslation(
      verseKey: json['verse_key'],
      text: json['text_uthmani_tajweed'],
    );
  }
}