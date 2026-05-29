// lib/pages/notification_settings_page.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _enabled = false;
  bool _loading = true;

  // Per-prayer toggles. Keys MUST match NotificationService._prayerKeyMap.
  final Map<String, bool> _perPrayer = {
    'subuh': true,
    'syuruk': true,
    'zohor': true,
    'asar': true,
    'maghrib': true,
    'isyak': true,
  };

  static const List<(String, String)> _prayerLabels = [
    ('subuh', 'Subuh'),
    ('syuruk', 'Syuruk'),
    ('zohor', 'Zohor'),
    ('asar', 'Asar'),
    ('maghrib', 'Maghrib'),
    ('isyak', 'Isyak'),
  ];

  // Currently selected sound id (key into NotificationService.availableSounds).
  String _selectedSoundId = 'silent';

  // In-app audio player used by the "Uji Bunyi & Getaran" button so the
  // sound is NOT limited by the iOS notification-banner timeout.
  final AudioPlayer _testPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _testPlayer.dispose();
    super.dispose();
  }

  /// Play the user's currently-selected sound through the in-app audio
  /// player (and trigger a vibration) — so testing isn't capped by the
  /// iOS Time-Sensitive banner duration.
  Future<void> _playTestSound() async {
    final sound = await NotificationService.instance.getSelectedSound();

    // Trigger a couple of strong haptic taps to mimic notification vibration.
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();

    if (!sound.playSound) return; // 'Getar Sahaja' — vibration only.

    // Resolve asset path: gendang uses .aac, everything else .wav
    final String? assetPath;
    if (sound.id == 'gendang') {
      assetPath = 'audio/gendang.aac';
    } else if (sound.ios != null) {
      assetPath = 'audio/${sound.ios}';
    } else {
      assetPath = null;
    }
    if (assetPath == null) return;

    try {
      await _testPlayer.stop();
      await _testPlayer.play(AssetSource(assetPath));
    } catch (_) {
      // Ignore playback errors — they don't affect the actual prayer-time
      // notification scheduling.
    }
  }

  Future<void> _loadStatus() async {
    final value = await NotificationService.instance.getNotificationsEnabled();

    final perPrayer = <String, bool>{};
    for (final p in _prayerLabels) {
      perPrayer[p.$1] =
      await NotificationService.instance.getPrayerEnabled(p.$1);
    }

    final selectedSound =
    await NotificationService.instance.getSelectedSound();

    if (!mounted) return;
    setState(() {
      _enabled = value;
      _perPrayer
        ..clear()
        ..addAll(perPrayer);
      _selectedSoundId = selectedSound.id;
      _loading = false;
    });
  }

  Future<void> _onSoundChanged(String id) async {
    setState(() {
      _selectedSoundId = id;
    });
    await NotificationService.instance.setSelectedSound(id);
    // Immediately preview the chosen sound so the user knows what to expect.
    // Uses the in-app player (not a notification) to bypass iOS banner timeout.
    await _playTestSound();
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
    // NOTE: actual rescheduling happens the next time the prayer-times
    // page loads its data (it calls scheduleForPrayerTimes()).
  }

  Future<void> _onPerPrayerToggle(String key, bool value) async {
    setState(() {
      _perPrayer[key] = value;
    });
    await NotificationService.instance.setPrayerEnabled(key, value);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

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
          : SingleChildScrollView(
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

            // ── Master switch card ───────────────────────────────
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

            // ── Per-prayer toggles (NEW) ─────────────────────────
            if (_enabled)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pilih Waktu Solat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                    for (int i = 0; i < _prayerLabels.length; i++) ...[
                      SwitchListTile(
                        dense: true,
                        activeColor: Colors.white,
                        activeTrackColor: primary,
                        title: Text(
                          _prayerLabels[i].$2,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _perPrayer[_prayerLabels[i].$1] ?? true,
                        onChanged: (v) =>
                            _onPerPrayerToggle(_prayerLabels[i].$1, v),
                      ),
                      if (i != _prayerLabels.length - 1)
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white12
                              : Colors.black12,
                        ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),

            if (_enabled) const SizedBox(height: 20),

            // ── SOUND PICKER (NEW) ────────────────────────────────
            if (_enabled)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            color: primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bunyi Notifikasi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (int i = 0;
                    i <
                        NotificationService.availableSounds.length;
                    i++) ...[
                      RadioListTile<String>(
                        dense: true,
                        activeColor: primary,
                        value: NotificationService.availableSounds[i].id,
                        groupValue: _selectedSoundId,
                        onChanged: (v) {
                          if (v == null) return;
                          _onSoundChanged(v);
                        },
                        title: Text(
                          NotificationService.availableSounds[i].label,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (i !=
                          NotificationService.availableSounds.length -
                              1)
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white12
                              : Colors.black12,
                        ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),

            if (_enabled) const SizedBox(height: 20),

            // ── TEST SOUND BUTTON ────────────────────────────────
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
                  onPressed: _playTestSound,
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

            // ── Info note ────────────────────────────────────────
            Text(
              'Nota:\n'
                  '• Memilih bunyi akan terus memainkan contoh.\n'
                  '• Jika notifikasi tidak keluar, pastikan MySolat dibenarkan '
                  'menerima notifikasi dalam tetapan sistem.\n'
                  '• Buka halaman Waktu Solat selepas mengubah tetapan ini '
                  'supaya jadual notifikasi dikemas kini dengan bunyi baru.',
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