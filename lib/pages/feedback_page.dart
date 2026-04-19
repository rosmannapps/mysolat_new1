import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // ---------------------------------------------------------------------------
  // 1. GOOGLE FORM CONFIG
  // ---------------------------------------------------------------------------

  // IMPORTANT: use formResponse, not viewform
  static const String _formUrl =
      'https://docs.google.com/forms/d/1WG1t5pIojMB2RpnaXcoXb57Xe5WzGgzy8nGLQcaH0Is/edit#responses';

  // Replace these entry IDs with your own
  static const String _fieldWaktuJelas = 'entry.233695841'; // Ya / Tidak
  static const String _fieldMudah = 'entry.810023621'; // 1..5
  static const String _fieldSyorkan = 'entry.1997193454'; // Ya / Tidak
  static const String _fieldRating = 'entry.1548486369'; // 1..5
  static const String _fieldKomen = 'entry.1967680197'; // free text

  // ---------------------------------------------------------------------------
  // 2. LOCAL STATE
  // ---------------------------------------------------------------------------

  String _waktuJelas = 'Ya';
  String _syorkan = 'Ya';

  int _mudah = 5; // 1..5
  int _rating = 5; // 1..5

  final TextEditingController _komenController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _komenController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 3. SUBMIT TO GOOGLE FORM
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final response = await http.post(
        Uri.parse(_formUrl),
        body: {
          _fieldWaktuJelas: _waktuJelas,
          _fieldMudah: _mudah.toString(),
          _fieldSyorkan: _syorkan,
          _fieldRating: _rating.toString(),
          _fieldKomen: _komenController.text,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 302) {
        // Reset local UI values
        setState(() {
          _waktuJelas = 'Ya';
          _syorkan = 'Ya';
          _mudah = 5;
          _rating = 5;
          _komenController.clear();
        });

        // Show iOS-style "Terima kasih" popup
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final scheme = Theme.of(ctx).colorScheme;
            final isDark = scheme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor:
              isDark ? const Color(0xFF111827) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Terima kasih!',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              content: Text(
                'Maklum balas anda telah diterima. Jazakallahu khairan!',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghantar maklum balas. Cuba lagi.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ralat rangkaian. Pastikan anda ada internet.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 4. UI HELPERS
  // ---------------------------------------------------------------------------

  Widget _yesNoSegment({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    const yesLabel = 'Ya';
    const noLabel = 'Tidak';
    final isYes = value == yesLabel;

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final labelColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _segmentedButton(
                text: yesLabel,
                selected: isYes,
                onTap: () => onChanged(yesLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _segmentedButton(
                text: noLabel,
                selected: !isYes,
                onTap: () => onChanged(noLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segmentedButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final bg = selected
        ? const Color(0xFF2563EB)
        : (isDark ? const Color(0xFF111827) : Colors.white);

    final border = selected
        ? const Color(0xFF2563EB)
        : (isDark ? Colors.white24 : Colors.grey.shade400);

    final fg = selected ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: fg,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _starsRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final labelColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i <= value ? Icons.star : Icons.star_border,
                    size: 28,
                    color: const Color(0xFFB7791F),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF4F4F7);
    final appBarFg = isDark ? Colors.white : Colors.black87;

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    final hintBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    final hintText = isDark ? Colors.white60 : Colors.black54;

    final smallLabel = isDark ? Colors.white70 : Colors.black87;
    final footerColor = isDark ? const Color(0xFF93C5FD) : Colors.blue;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: appBarFg),
        title: Text(
          'Maklum Balas',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            color: appBarFg,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _yesNoSegment(
                    label: 'Waktu solat jelas &\nmudah dilihat',
                    value: _waktuJelas,
                    onChanged: (v) => setState(() => _waktuJelas = v),
                  ),
                  const SizedBox(height: 16),
                  _starsRow(
                    label: 'Mudah digunakan',
                    value: _mudah,
                    onChanged: (v) => setState(() => _mudah = v),
                  ),
                  const SizedBox(height: 16),
                  _yesNoSegment(
                    label: 'Akan syorkan\nkepada rakan?',
                    value: _syorkan,
                    onChanged: (v) => setState(() => _syorkan = v),
                  ),
                  const SizedBox(height: 16),
                  _starsRow(
                    label: 'Penilaian keseluruhan',
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Komen / Cadangan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: smallLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: hintBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.transparent,
                      ),
                    ),
                    child: TextField(
                      controller: _komenController,
                      minLines: 4,
                      maxLines: 6,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                        hintText: 'Komen / cadangan anda...',
                        hintStyle: TextStyle(color: hintText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Hantar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Terima kasih atas maklum balas anda 🙏',
                style: TextStyle(
                  fontSize: 10,
                  color: footerColor,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}