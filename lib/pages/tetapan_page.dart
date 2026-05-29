// lib/pages/tetapan_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_page.dart';
import 'arah_qiblat_page.dart';
import 'notification_settings_page.dart';
import 'youtube_page.dart';
import 'feedback_page.dart';
import 'jadual_bulanan_page.dart';

class TetapanPage extends StatelessWidget {
  const TetapanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // ✅ Prevent extreme system font scaling from breaking cards
    final clampedTextScale = mq.textScaler.clamp(
      minScaleFactor: 0.95,
      maxScaleFactor: 1.08,
    );

    final size = mq.size;
    final w = size.width;
    final h = size.height;

    final isTinyWidth = w < 340;
    final isSmallWidth = w < 360;
    final isSmallHeight = h < 740;
    final isVerySmall = isTinyWidth || (isSmallWidth && isSmallHeight);

    // ✅ Columns: 1 for super narrow devices, else 2
    final crossAxisCount = isTinyWidth ? 1 : 2;

    // ✅ Card height safer (shorter to avoid bottom overflow)
    final cardExtent = isVerySmall ? 150.0 : (isSmallHeight ? 146.0 : 142.0);

    // ✅ Font sizes
    final titleSize = isVerySmall ? 17.0 : 18.0;
    final subSize = isVerySmall ? 12.5 : 13.0;

    // ✅ Default lines
    const defaultTitleLines = 2;
    const defaultSubtitleLines = 2;

    // ✅ Padding/spacing inside card (tighter)
    final padH = isVerySmall ? 12.0 : 13.0;
    final padTop = isVerySmall ? 12.0 : 13.0;
    final iconBox = isVerySmall ? 40.0 : 42.0;
    final gapAfterTopRow = isVerySmall ? 8.0 : 9.0;
    final gapTitleSub = isVerySmall ? 4.0 : 5.0;

    const bg = Color(0xFFF3F6F1);
    const accent = Color(0xFF2F5D46);

    void go(Widget page) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    final items = <_SettingCardItem>[
      _SettingCardItem(
        title: 'Arah Qiblat',
        subtitle: 'Arah kiblat & kompas',
        icon: Icons.explore_rounded,
        iconBg: const Color(0xFFE3EEE8),
        iconColor: accent,
        dotColor: const Color(0xFF7C8F84),
        onTap: () => go(const ArahQiblatPage()),
      ),
      _SettingCardItem(
        title: 'YouTube',
        subtitle: 'Video & saluran pilihan',
        icon: Icons.play_circle_fill_rounded,
        iconBg: const Color(0xFFF4E6E3),
        iconColor: const Color(0xFFD84A3A),
        dotColor: const Color(0xFFBFA09B),
        onTap: () => go(const YouTubePage()),
      ),
      _SettingCardItem(
        title: 'Jadual Solat\nBulanan',
        subtitle: 'Kalendar & jadual',
        icon: Icons.calendar_month_rounded,
        iconBg: const Color(0xFFE6ECFB),
        iconColor: const Color(0xFF2D63D7),
        dotColor: const Color(0xFF96A6C8),
        onTap: () => go(const JadualBulananPage()),
      ),
      _SettingCardItem(
        title: 'Notifikasi',
        subtitle: 'Tetapan notifikasi',
        icon: Icons.notifications_rounded,
        iconBg: const Color(0xFFF1E9E3),
        iconColor: const Color(0xFF8B4A25),
        dotColor: const Color(0xFFC2A38F),
        onTap: () => go(const NotificationSettingsPage()),
      ),
      _SettingCardItem(
        title: 'Maklum Balas',
        subtitle: 'Cadangan & laporan isu',
        // ✅ Fix overflow: force subtitle to 1 line only for this card
        subtitleMaxLines: 1,
        icon: Icons.chat_bubble_rounded,
        iconBg: const Color(0xFFEDE9E4),
        iconColor: const Color(0xFF6B4E3B),
        dotColor: const Color(0xFFB9A79D),
        onTap: () => go(const FeedbackPage()),
      ),
      _SettingCardItem(
        title: 'Tentang MySolat',
        subtitle: 'Kata Pengantar',
        icon: Icons.info_rounded,
        iconBg: const Color(0xFFE9E6F7),
        iconColor: const Color(0xFF5B3FD6),
        dotColor: const Color(0xFFA49AD8),
        onTap: () => go(const AboutPage()),
      ),
    ];

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedTextScale),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                sliver: SliverToBoxAdapter(
                  child: const _Header(
                    title: 'Tetapan',
                    subtitle: 'Urus ciri tambahan & maklumat aplikasi',
                    accent: accent,
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: cardExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final it = items[i];
                      return _SettingCard(
                        item: it,
                        titleSize: titleSize,
                        subSize: subSize,
                        titleLines: it.titleMaxLines ?? defaultTitleLines,
                        subtitleLines: it.subtitleMaxLines ?? defaultSubtitleLines,
                        padH: padH,
                        padTop: padTop,
                        iconBox: iconBox,
                        gapAfterTopRow: gapAfterTopRow,
                        gapTitleSub: gapTitleSub,
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),

              // ── "Sokong MySolat" donation card ──
              // Tappable full-width card that opens https://mysolat.rosmannapps.com/sokong/
              // in the user's default browser. Payment processing happens
              // entirely on the external website — no personal phone number
              // or bank account details are shown inside the app.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _SokongCard(
                    accent: accent,
                    onTap: () => _openSokongPage(context),
                  ),
                ),
              ),

              // ── "Hubungi Kami" contact card ──
              // Directs users to mysolat.rosmannapps.com for all communication.
              // No personal phone number or bank details in the app.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _HubungiCard(
                    accent: accent,
                    onTap: () => _openHubungiPage(context),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                sliver: const SliverToBoxAdapter(
                  child: _TipCard(
                    accent: accent,
                    text: 'Semoga aplikasi ini membantu memudahkan ibadah harian anda.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.settings_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color dotColor;
  final VoidCallback onTap;

  final int? titleMaxLines;
  final int? subtitleMaxLines;

  _SettingCardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.dotColor,
    required this.onTap,
    this.titleMaxLines,
    this.subtitleMaxLines,
  });
}

class _SettingCard extends StatelessWidget {
  final _SettingCardItem item;

  final double titleSize;
  final double subSize;
  final int titleLines;
  final int subtitleLines;

  final double padH;
  final double padTop;
  final double iconBox;
  final double gapAfterTopRow;
  final double gapTitleSub;

  const _SettingCard({
    required this.item,
    required this.titleSize,
    required this.subSize,
    required this.titleLines,
    required this.subtitleLines,
    required this.padH,
    required this.padTop,
    required this.iconBox,
    required this.gapAfterTopRow,
    required this.gapTitleSub,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(padH, padTop, padH, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: item.iconBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Icon(item.icon, color: item.iconColor),
                    ),
                    const Spacer(),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gapAfterTopRow),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: titleLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          height: 1.06,
                          color: Colors.black.withOpacity(0.88),
                        ),
                      ),
                      SizedBox(height: gapTitleSub),
                      Text(
                        item.subtitle,
                        maxLines: subtitleLines,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: subSize,
                          fontWeight: FontWeight.w700,
                          height: 1.20,
                          color: Colors.black.withOpacity(0.58),
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
  }
}

/// Opens the MySolat donation page in the user's default browser.
/// Opens a URL trying inAppBrowserView first, then falling back to
/// externalApplication. Returns true if the URL was launched successfully.
Future<bool> _launchWithFallback(Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return true;
  } catch (_) {}
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {}
  return false;
}

/// Directs to mysolat.rosmannapps.com/sokong/ — no personal phone number or
/// bank account details are shown inside the app.
Future<void> _openSokongPage(BuildContext context) async {
  final uri = Uri.parse('https://mysolat.rosmannapps.com/sokong/');
  final ok = await _launchWithFallback(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tidak dapat membuka pelayar. Sila lawati mysolat.rosmannapps.com/sokong secara manual.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

/// Opens the mysolat.rosmannapps.com contact/communication page.
Future<void> _openHubungiPage(BuildContext context) async {
  final uri = Uri.parse('https://mysolat.rosmannapps.com/hubungi/');
  final ok = await _launchWithFallback(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tidak dapat membuka pelayar. Sila lawati mysolat.rosmannapps.com secara manual.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

/// Full-width donation card shown between the settings grid and the bottom
/// tip card. Friendly green styling, heart icon, BM copy that frames the
/// donation as voluntary support rather than payment.
class _SokongCard extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _SokongCard({
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sokong MySolat Malaysia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sumbangan anda membantu kami mengekalkan dan menambah baik aplikasi ini.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.65),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withOpacity(0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width contact card. Tapping it opens mysolat.rosmannapps.com/hubungi/
/// so users can reach the developer without needing a personal phone
/// number or bank account details inside the app.
class _HubungiCard extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _HubungiCard({
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const contactColor = Color(0xFF1A6FA6); // blue tone for contact

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: contactColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: contactColor.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: contactColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.mail_rounded,
                  color: contactColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hubungi Kami',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: contactColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cadangan, pertanyaan atau maklum balas — lawati mysolat.rosmannapps.com',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.65),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: contactColor.withOpacity(0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Color accent;
  final String text;

  const _TipCard({
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.lightbulb_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.70),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}