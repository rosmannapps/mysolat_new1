// lib/pages/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import '../services/azan_audio_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _enabled = false;
  AzanSoundMode _soundMode = AzanSoundMode.azanOnly;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final notif = await NotificationService.instance.getNotificationsEnabled();
    final mode = await AzanAudioService.instance.getSoundMode();
    if (!mounted) return;
    setState(() {
      _enabled = notif;
      _soundMode = mode;
      _loading = false;
    });
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    await NotificationService.instance.setNotificationsEnabled(value);
    if (value) {
      await NotificationService.instance.showSimpleNotification(
        title: 'Notifikasi Diaktifkan',
        body: 'Anda akan menerima notifikasi waktu solat.',
      );
    }
  }

  Future<void> _onModeChanged(AzanSoundMode mode) async {
    setState(() => _soundMode = mode);
    await AzanAudioService.instance.setSoundMode(mode);
  }

  Future<void> _testSound() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
    switch (_soundMode) {
      case AzanSoundMode.none:
        break;
      case AzanSoundMode.azanOnly:
        await AzanAudioService.instance.playAzan();
        break;
      case AzanSoundMode.beepOnly:
        await Future.delayed(const Duration(milliseconds: 300));
        await NotificationService.instance.showTestNotification();
        break;
      case AzanSoundMode.beepAndAzan:
        await AzanAudioService.instance.playAzan();
        await Future.delayed(const Duration(milliseconds: 300));
        await NotificationService.instance.showTestNotification();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);
    const azanColor = Color(0xFF1F5E3E);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0F14) : const Color(0xFFF5F5F5);
    final appBarBg = isDark ? const Color(0xFF0B0F14) : Colors.white;
    final appBarFg = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black87;
    final subtleColor = isDark ? Colors.white60 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0.5,
      ),
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Text('Tetapan Notifikasi Waktu Solat',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: titleColor)),
                  const SizedBox(height: 8),
                  Text(
                    'Apabila diaktifkan, telefon anda akan mengeluarkan bunyi '
                        'notifikasi apabila masuk waktu solat.',
                    style:
                        TextStyle(fontSize: 14, height: 1.4, color: bodyColor),
                  ),
                  const SizedBox(height: 24),

                  // Notification toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded,
                            color: primary, size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text('Notifikasi Waktu Solat',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor)),
                        ),
                        Switch(
                          value: _enabled,
                          activeColor: Colors.white,
                          activeTrackColor: primary,
                          inactiveThumbColor: isDark ? Colors.white70 : null,
                          inactiveTrackColor: isDark ? Colors.white24 : null,
                          onChanged: _onToggle,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sound mode selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mosque_rounded,
                                color: azanColor, size: 26),
                            const SizedBox(width: 10),
                            Text('Jenis Bunyi',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SoundModeOption(
                          label: 'Tiada bunyi',
                          subtitle: 'Notifikasi senyap sahaja',
                          icon: Icons.notifications_off_outlined,
                          mode: AzanSoundMode.none,
                          selected: _soundMode,
                          titleColor: titleColor,
                          accentColor: azanColor,
                          onTap: () => _onModeChanged(AzanSoundMode.none),
                        ),
                        _SoundModeOption(
                          label: 'Azan sahaja',
                          subtitle: 'Allahu Akbar apabila masuk waktu',
                          icon: Icons.record_voice_over_rounded,
                          mode: AzanSoundMode.azanOnly,
                          selected: _soundMode,
                          titleColor: titleColor,
                          accentColor: azanColor,
                          onTap: () =>
                              _onModeChanged(AzanSoundMode.azanOnly),
                        ),
                        _SoundModeOption(
                          label: 'Beep sahaja',
                          subtitle: 'Bunyi notifikasi biasa',
                          icon: Icons.notifications_rounded,
                          mode: AzanSoundMode.beepOnly,
                          selected: _soundMode,
                          titleColor: titleColor,
                          accentColor: azanColor,
                          onTap: () =>
                              _onModeChanged(AzanSoundMode.beepOnly),
                        ),
                        _SoundModeOption(
                          label: 'Beep + Azan',
                          subtitle: 'Bunyi notifikasi diikuti Azan Intro',
                          icon: Icons.surround_sound_rounded,
                          mode: AzanSoundMode.beepAndAzan,
                          selected: _soundMode,
                          titleColor: titleColor,
                          accentColor: azanColor,
                          onTap: () =>
                              _onModeChanged(AzanSoundMode.beepAndAzan),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Test button
                  if (_enabled)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azanColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _testSound,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Uji Bunyi Sekarang',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    Text('Aktifkan notifikasi untuk menguji bunyi.',
                        style: TextStyle(fontSize: 13, color: subtleColor)),

                  const SizedBox(height: 20),

                  Text(
                    'Nota:\n'
                        '• Anda boleh mengubah tetapan bunyi di sistem telefon.\n'
                        '• Jika notifikasi tidak keluar, pastikan MySolat dibenarkan '
                        'menerima notifikasi dalam tetapan sistem.',
                    style: TextStyle(
                        fontSize: 13, height: 1.4, color: bodyColor),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SoundModeOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final AzanSoundMode mode;
  final AzanSoundMode selected;
  final Color titleColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _SoundModeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.selected,
    required this.titleColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color:
                    isSelected ? accentColor : titleColor.withOpacity(0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? accentColor : titleColor)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: titleColor.withOpacity(0.5))),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? accentColor
                  : titleColor.withOpacity(0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
