// lib/pages/notification_settings_page.dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../services/azan_audio_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final value = await NotificationService.instance.getNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _loading = false;
    });
  }

  Future<void> _onToggle(bool value) async {
    setState(() {
      _enabled = value;
    });
    await NotificationService.instance.setNotificationsEnabled(value);

    if (value) {
      await NotificationService.instance.showSimpleNotification(
        title: 'Notifikasi Diaktifkan',
        body: 'Anda akan menerima notifikasi waktu solat.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // ✅ Dark-mode friendly colors (keeps your layout the same)
    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF5F5F5);
    final appBarBg = isDark ? const Color(0xFF0B0F14) : Colors.white;
    final appBarFg = isDark ? Colors.white : Colors.black87;

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black87;
    final subtleColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0.5,
      ),
      backgroundColor: bg,
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tetapan Notifikasi Waktu Solat',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Apabila diaktifkan, telefon anda akan mengeluarkan bunyi '
                  'notifikasi ringkas apabila masuk waktu solat.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: bodyColor,
              ),
            ),
            const SizedBox(height: 24),

            // Master switch card
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: primary,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Notifikasi Waktu Solat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    activeColor: Colors.white,
                    activeTrackColor: primary,
                    inactiveThumbColor: isDark ? Colors.white70 : null,
                    inactiveTrackColor:
                    isDark ? Colors.white24 : null,
                    onChanged: _onToggle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // TEST SOUND BUTTON
            if (_enabled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    // Trigger strong haptic immediately (works on iOS + Android)
                    await HapticFeedback.heavyImpact();
                    await Future.delayed(const Duration(milliseconds: 200));
                    await HapticFeedback.heavyImpact();
                    await Future.delayed(const Duration(milliseconds: 200));
                    await HapticFeedback.heavyImpact();
                    // Play Azan audio
                    await AzanAudioService.instance.playAzan();
                    // Short delay so iOS registers it properly
                    await Future.delayed(const Duration(milliseconds: 300));
                    await NotificationService.instance.showTestNotification();
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text(
                    'Uji Bunyi & Getaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              Text(
                'Aktifkan notifikasi untuk menguji bunyi.',
                style: TextStyle(
                  fontSize: 13,
                  color: subtleColor,
                ),
              ),

            const SizedBox(height: 20),

            // Info note
            Text(
              'Nota:\n'
                  '• Anda boleh mengubah tetapan bunyi di sistem telefon.\n'
                  '• Jika notifikasi tidak keluar, pastikan MySolat dibenarkan '
                  'menerima notifikasi dalam tetapan sistem.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: bodyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}