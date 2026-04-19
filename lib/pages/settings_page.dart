import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arah_qiblat_page.dart';
import 'youtube_page.dart';
import 'jadual_bulanan_page.dart';
import 'notification_settings_page.dart';
import 'feedback_page.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // AppTheme palette (matches your icon)
    const emerald = AppTheme.primary;
    const gold = AppTheme.accent;

    final bg = AppTheme.bgOf(context);

    final items = <_SettingsItem>[
      _SettingsItem(
        title: 'Arah Qiblat',
        icon: Icons.explore_rounded,
        // Keep feature identity but still within theme
        tint: emerald,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArahQiblatPage()),
        ),
      ),
      _SettingsItem(
        title: 'YouTube',
        icon: Icons.play_circle_fill_rounded,
        tint: const Color(0xFFE53935),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const YouTubePage()),
        ),
      ),
      _SettingsItem(
        title: 'Jadual Solat\nBulanan',
        icon: Icons.table_chart_rounded,
        tint: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JadualBulananPage()),
        ),
      ),
      _SettingsItem(
        title: 'Notifikasi',
        icon: Icons.notifications_active_rounded,
        tint: const Color(0xFF9B4F23),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
        ),
      ),
      _SettingsItem(
        title: 'Maklum Balas',
        icon: Icons.chat_rounded,
        tint: const Color(0xFF7F6147),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FeedbackPage()),
        ),
      ),
      _SettingsItem(
        title: 'About',
        icon: Icons.info_rounded,
        tint: const Color(0xFF5B2ECC),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutPage()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Tetapan'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: GridView.builder(
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final it = items[index];
              return _SettingsTile(
                title: it.title,
                icon: it.icon,
                tint: it.tint,
                primary: emerald,
                gold: gold,
                onTap: it.onTap,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsItem {
  final String title;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.title,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tint;
  final Color primary;
  final Color gold;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.icon,
    required this.tint,
    required this.primary,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final surface = cs.surface;
    final border = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final shadow = isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.08);

    // Icon badge colors
    final badgeBg = isDark
        ? Color.alphaBlend(tint.withOpacity(0.26), const Color(0xFF121417))
        : tint.withOpacity(0.12);

    final titleColor = cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Icon(icon, color: tint, size: 26),
                    ),
                    const Spacer(),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: gold.withOpacity(isDark ? 0.85 : 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'Buka',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primary.withOpacity(isDark ? 0.95 : 0.92),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: primary.withOpacity(isDark ? 0.95 : 0.92),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}