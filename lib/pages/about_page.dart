import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final isDark = theme.brightness == Brightness.dark;

    final bg = cs.background;
    final surface = cs.surface;
    final outline = cs.outlineVariant;

    final primary = cs.primary;
    final textPrimary = cs.onBackground;
    final textSecondary = cs.onBackground.withOpacity(isDark ? 0.76 : 0.72);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          'Tentang MySolat',
          style:
              tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: primary,
              ) ??
              TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 380,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: outline.withOpacity(isDark ? 0.55 : 0.85),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.32 : 0.06,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ',
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'KFGQPC',
                                  fontSize: 20,
                                  height: 1.6,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'MySolat',
                                textAlign: TextAlign.center,
                                style:
                                    tt.titleLarge?.copyWith(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ) ??
                                    TextStyle(
                                      color: textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Ringkas • Tepat • Mesra Pengguna',
                                textAlign: TextAlign.center,
                                style:
                                    tt.bodyMedium?.copyWith(
                                      color: textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ) ??
                                    TextStyle(
                                      color: textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "MySolat App dibangunkan untuk memudahkan umat Islam mendapatkan "
                                "maklumat waktu solat dengan paparan yang ringkas, jelas, dan "
                                "sesuai untuk semua peringkat pengguna. Aplikasi ini menyediakan "
                                "waktu solat yang tepat di seluruh Malaysia, bersumberkan secara "
                                "rasmi daripada JAKIM.\n\n"
                                "Selain itu, MySolat App turut dilengkapi dengan pelbagai ciri "
                                "bermanfaat seperti bacaan al-Quran, panduan arah Qiblat, zikir "
                                "harian (pagi & petang), serta akses kepada kandungan Islam yang "
                                "sahih. Aplikasi ini juga menghubungkan pengguna dengan saluran "
                                "YouTube bagi memperluas perkongsian ilmu yang bermanfaat.\n\n"
                                "Setinggi-tinggi penghargaan ditujukan kepada OpenAI kerana "
                                "membantu saya dalam proses pembelajaran, pengekodan, serta "
                                "membangunkan projek ini langkah demi langkah.\n\n"
                                "Alhamdulillah, semoga usaha kecil ini diterima oleh Allah sebagai "
                                "amal jariah. Amin Ya Rabbal 'Alamin.",
                                textAlign: TextAlign.justify,
                                style:
                                    tt.bodyMedium?.copyWith(
                                      color: textPrimary,
                                      fontSize: 14,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ) ??
                                    TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(
                                    isDark ? 0.14 : 0.06,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: primary.withOpacity(0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(
                                          isDark ? 0.22 : 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Rosman Daud',
                                            style:
                                                tt.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: textPrimary,
                                                ) ??
                                                TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Pembangun MySolat',
                                            style:
                                                tt.bodySmall?.copyWith(
                                                  color: textSecondary,
                                                  fontWeight: FontWeight.w700,
                                                ) ??
                                                TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
