// lib/tajwid/tajwid_parser.dart
class TajweedSpan {
  final String text;      // displayed text
  final String? rule;     // tajweed rule name (e.g. ham_wasl) or 'end'
  const TajweedSpan(this.text, this.rule);
}

class TajweedParseResult {
  final List<TajweedSpan> spans;
  const TajweedParseResult(this.spans);
}

class TajweedParser {
  /// Parses Quran.com tajweed HTML-like markup into spans.
  /// Supports:
  ///   <tajweed class=RULE> ... </tajweed>
  ///   <span class=end>١</span>
  static TajweedParseResult parse(String input) {
    if (input.isEmpty) return const TajweedParseResult([]);

    final spans = <TajweedSpan>[];

    // Match:
    // <tajweed class=ham_wasl>ٱ</tajweed>
    // <tajweed class="ham_wasl">ٱ</tajweed>
    // <span class=end>١</span>
    // <span class="end">١</span>
    final tagRe = RegExp(
      r'''<(tajweed|span)\s+class=(?:"([^"]+)"|'([^']+)'|([A-Za-z0-9_\-]+))\s*>(.*?)</\1>''',
      dotAll: true,
      caseSensitive: false,
    );

    int last = 0;

    for (final m in tagRe.allMatches(input)) {
      // Add plain text before this tag
      if (m.start > last) {
        final plain = input.substring(last, m.start);
        if (plain.isNotEmpty) {
          spans.add(TajweedSpan(_stripOtherTags(plain), null));
        }
      }

      final tagName = (m.group(1) ?? '').toLowerCase();

      final cls = (m.group(2) ?? m.group(3) ?? m.group(4) ?? '').trim();
      final inner = m.group(5) ?? '';

      if (tagName == 'span' && cls.toLowerCase() == 'end') {
        spans.add(TajweedSpan(_stripOtherTags(inner), 'end'));
      } else {
        spans.add(TajweedSpan(_stripOtherTags(inner), cls.isEmpty ? null : cls));
      }

      last = m.end;
    }

    // Add remaining plain text
    if (last < input.length) {
      final tail = input.substring(last);
      if (tail.isNotEmpty) {
        spans.add(TajweedSpan(_stripOtherTags(tail), null));
      }
    }

    // Remove empty spans
    final cleaned = spans.where((s) => s.text.isNotEmpty).toList();
    return TajweedParseResult(cleaned);
  }

  // Safety: if any weird tags remain, remove them.
  static String _stripOtherTags(String s) {
    return s.replaceAll(RegExp(r'<[^>]+>'), '');
  }
}