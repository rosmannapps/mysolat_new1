// lib/services/notification_service.dart
//
// Handles ALL local notifications for MySolat:
//   • Master ON/OFF toggle (existing)
//   • Per-prayer ON/OFF toggle (NEW)
//   • Schedules an azan notification for each of the 5 daily prayers
//     using zonedSchedule() so it fires even when the app is killed
//     or the screen is off (NEW)
//
// IMPORTANT: main.dart MUST initialise the timezone database BEFORE
// runApp() is called, otherwise zonedSchedule() throws.
//
// Required Android permissions in AndroidManifest.xml:
//   POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM,
//   RECEIVE_BOOT_COMPLETED, WAKE_LOCK, VIBRATE
// + the ScheduledNotificationBootReceiver from the plugin.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_times.dart';

/// One entry in the notification-sound chooser.
class NotifSound {
  final String id;        // unique key saved in SharedPreferences
  final String label;     // user-facing label
  final String? android;  // raw resource name (no extension), or null = default
  final String? ios;      // bundled filename WITH extension, or null = default
  final bool playSound;   // false = silent (vibrate only)

  const NotifSound({
    required this.id,
    required this.label,
    required this.android,
    required this.ios,
    this.playSound = true,
  });
}

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Master switch
  static const String _prefKeyEnabled = 'notifications_enabled';

  // Selected sound (key into [availableSounds]).
  static const String _prefKeySound = 'notif_sound';
  static const String _defaultSoundId = 'silent'; // default = vibrate only

  // Per-prayer switches (default = ON when master is ON).
  static const String _prefKeySubuh   = 'notif_prayer_subuh';
  static const String _prefKeySyuruk  = 'notif_prayer_syuruk';
  static const String _prefKeyZohor   = 'notif_prayer_zohor';
  static const String _prefKeyAsar    = 'notif_prayer_asar';
  static const String _prefKeyMaghrib = 'notif_prayer_maghrib';
  static const String _prefKeyIsyak   = 'notif_prayer_isyak';

  // ----------------------------------------------------------------------
  // AVAILABLE SOUNDS
  //
  // For each sound:
  //   id        — the key we save in SharedPreferences
  //   label     — what we show in the UI
  //   android   — base filename (NO extension) in android/app/src/main/res/raw/
  //               (must be lowercase, e.g. beep_azan.mp3)
  //   ios       — full filename WITH extension, bundled with Runner target in
  //               Xcode (e.g. beep_azan.caf or beep_azan.aiff or .wav)
  //
  // 'default' = use the OS system notification sound; no file needed.
  // ----------------------------------------------------------------------
  static const List<NotifSound> availableSounds = [
    NotifSound(
      id: _defaultSoundId,
      label: 'Getar Sahaja',
      android: null,
      ios: null,
      playSound: false,         // silent — vibrate only
    ),
    NotifSound(
      id: 'beep',
      label: 'Beep + Getar',
      android: 'beep',          // android/app/src/main/res/raw/beep.wav
      ios: 'beep.wav',          // bundled in Runner (Xcode)
    ),
    NotifSound(
      id: 'gendang',
      label: 'Gendang + Getar',
      android: 'gendang',       // android/app/src/main/res/raw/gendang.aac
      ios: 'gendang.wav',       // bundled in Runner (Xcode)
    ),
  ];

  // Channel for the azan / prayer-time alerts.
  static const String _channelId = 'prayer_times_channel_v3';
  static const String _channelName = 'Notifikasi Waktu Solat';

  // Deterministic notification IDs (so re-scheduling overwrites cleanly).
  static const int _idSubuh   = 1001;
  static const int _idSyuruk  = 1002;
  static const int _idZohor   = 1003;
  static const int _idAsar    = 1004;
  static const int _idMaghrib = 1005;
  static const int _idIsyak   = 1006;

  // ----------------------------------------------------------------------
  // INITIALISATION
  // ----------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(settings);

    // ANDROID 13+ runtime POST_NOTIFICATIONS + exact-alarm permission.
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Notification permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      // Exact-alarm permission (Android 12+). Without this the system
      // will silently downgrade our schedule to inexact and may delay
      // the azan by minutes — defeating the purpose.
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  // ----------------------------------------------------------------------
  // PREFERENCES: MASTER ON/OFF
  // ----------------------------------------------------------------------

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? false;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, value);

    await _ensureInitialized();

    if (!value) {
      // Master OFF: cancel everything (scheduled + shown).
      await _plugin.cancelAll();
    }
  }

  // ----------------------------------------------------------------------
  // PREFERENCES: PER-PRAYER ON/OFF
  // ----------------------------------------------------------------------

  static const Map<String, String> _prayerKeyMap = {
    'subuh':   _prefKeySubuh,
    'syuruk':  _prefKeySyuruk,
    'zohor':   _prefKeyZohor,
    'asar':    _prefKeyAsar,
    'maghrib': _prefKeyMaghrib,
    'isyak':   _prefKeyIsyak,
  };

  /// Default = true (notify for every prayer when master switch is on).
  Future<bool> getPrayerEnabled(String prayer) async {
    final key = _prayerKeyMap[prayer.toLowerCase()];
    if (key == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<void> setPrayerEnabled(String prayer, bool value) async {
    final key = _prayerKeyMap[prayer.toLowerCase()];
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ----------------------------------------------------------------------
  // PREFERENCES: SELECTED SOUND
  // ----------------------------------------------------------------------

  /// Returns the currently-selected [NotifSound]. Falls back to the
  /// default system sound if the saved id is unknown.
  Future<NotifSound> getSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKeySound) ?? _defaultSoundId;
    return availableSounds.firstWhere(
          (s) => s.id == id,
      orElse: () => availableSounds.first,
    );
  }

  Future<void> setSelectedSound(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySound, id);
    // Re-schedule with the new sound right away if anything is armed.
    // (Caller can also re-load the Solat page to refresh, but doing it
    //  here is a nicer UX.)
    // We can't easily rebuild the schedule here without the prayer times,
    // so we just cancel — the next time the Solat page loads it will
    // re-arm with the new sound.
    await cancelPrayerTimes();
  }

  // ----------------------------------------------------------------------
  // COMMON NOTIFICATION DETAILS (sound + vibration)
  // ----------------------------------------------------------------------

  /// Builds platform-specific notification details using [sound].
  /// If [sound] is null, falls back to the user's saved preference,
  /// then to the default system sound.
  NotificationDetails _buildPlatformDetails({NotifSound? sound}) {
    final vibrationPattern = Int64List.fromList([0, 600, 250, 600]);

    // Use the channel id matching the sound so Android actually picks up
    // a sound change (channel sound is locked once created). 'default'
    // uses the original channel.
    final channelId = (sound == null || sound.id == _defaultSoundId)
        ? _channelId
        : '${_channelId}_${sound.id}';
    final channelName = (sound == null || sound.id == _defaultSoundId)
        ? _channelName
        : '$_channelName (${sound.label})';

    final playSound = sound?.playSound ?? true;

    final androidSound = (!playSound || sound?.android == null)
        ? null
        : RawResourceAndroidNotificationSound(sound!.android!);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Pemberitahuan apabila masuk waktu solat.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      sound: androidSound,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      // category + fullScreenIntent help Android wake the screen for the azan.
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
      visibility: NotificationVisibility.public,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: playSound,
      presentBadge: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
      sound: playSound ? sound?.ios : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  // ----------------------------------------------------------------------
  // SIMPLE / TEST NOTIFICATIONS (existing behaviour, unchanged callers)
  // ----------------------------------------------------------------------

  Future<void> showSimpleNotification({
    int id = 0,
    String title = 'Waktu Solat',
    String body = 'Ini contoh notifikasi.',
  }) async {
    await _ensureInitialized();
    final enabled = await getNotificationsEnabled();
    if (!enabled) return;
    final sound = await getSelectedSound();
    await _plugin.show(id, title, body, _buildPlatformDetails(sound: sound));
  }

  /// Plays the test notification with the chosen sound (defaults to the
  /// user's saved preference if [sound] is null).
  Future<void> showTestNotification({NotifSound? sound}) async {
    await _ensureInitialized();
    final enabled = await getNotificationsEnabled();
    if (!enabled) return;
    final s = sound ?? await getSelectedSound();
    await _plugin.show(
      999,
      'Uji Bunyi & Getaran',
      'Jika anda dengar bunyi dan rasa getaran, notifikasi berfungsi.',
      _buildPlatformDetails(sound: s),
    );
  }

  // ======================================================================
  // SCHEDULED PRAYER-TIME NOTIFICATIONS (the actual azan fix)
  // ======================================================================

  /// Schedule today's 5 azan notifications + Syuruk (to mark end of Subuh).
  /// Skips any time that has already passed.
  ///
  /// Time strings accepted in either format:
  ///   "HH:mm" / "HH:mm:ss"   (24-hour, e.g. "05:42:00")
  ///   "h:mm AM/PM"           (12-hour, e.g. "5:42 AM")
  Future<void> scheduleForPrayerTimes({
    required DateTime date,
    required PrayerTimes times,
  }) async {
    await _ensureInitialized();

    final master = await getNotificationsEnabled();
    if (!master) {
      // Master OFF — make sure nothing is left scheduled.
      await cancelPrayerTimes();
      return;
    }

    // Always cancel previous schedules first so we don't double-fire.
    await cancelPrayerTimes();

    // Resolve the user's chosen sound ONCE so every prayer this round
    // shares the same channel id / iOS sound file.
    final sound = await getSelectedSound();
    final details = _buildPlatformDetails(sound: sound);

    final entries = <(int, String, String, String)>[
      (_idSubuh,   'subuh',   'Waktu Subuh',   times.subuh),
      (_idSyuruk,  'syuruk',  'Waktu Syuruk',  times.syuruk),
      (_idZohor,   'zohor',   'Waktu Zohor',   times.zohor),
      (_idAsar,    'asar',    'Waktu Asar',    times.asar),
      (_idMaghrib, 'maghrib', 'Waktu Maghrib', times.maghrib),
      (_idIsyak,   'isyak',   'Waktu Isyak',   times.isyak),
    ];

    final now = DateTime.now();

    for (final e in entries) {
      final id = e.$1;
      final key = e.$2;
      final title = e.$3;
      final raw = e.$4;

      // Per-prayer toggle
      final on = await getPrayerEnabled(key);
      if (!on) continue;

      final dt = _parseTimeOnDate(raw, date);
      if (dt == null) continue;

      // Skip times already in the past (so we don't fire late).
      if (!dt.isAfter(now)) continue;

      final tzDt = tz.TZDateTime.from(dt, tz.local);

      await _plugin.zonedSchedule(
        id,
        title,
        'Telah masuk $title.',
        tzDt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // payload could be useful later for routing to the prayer page.
        payload: 'prayer:$key',
      );
    }
  }

  /// Cancel only the prayer-time slot notifications (leaves test ones alone).
  Future<void> cancelPrayerTimes() async {
    await _ensureInitialized();
    for (final id in [
      _idSubuh,
      _idSyuruk,
      _idZohor,
      _idAsar,
      _idMaghrib,
      _idIsyak,
    ]) {
      await _plugin.cancel(id);
    }
  }

  /// Returns the list of currently scheduled (pending) notifications —
  /// useful for debugging from a hidden settings tap.
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    await _ensureInitialized();
    return _plugin.pendingNotificationRequests();
  }

  // ----------------------------------------------------------------------
  // TIME PARSING
  // ----------------------------------------------------------------------

  /// Parse a JAKIM/AlAdhan time string and combine it with [date].
  /// Returns null if the input can't be parsed.
  DateTime? _parseTimeOnDate(String raw, DateTime date) {
    if (raw.trim().isEmpty) return null;

    final s = raw.trim().toUpperCase();

    // Case A: 12-hour "h:mm AM/PM"
    if (s.contains('AM') || s.contains('PM')) {
      final isPm = s.contains('PM');
      final stripped = s.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = stripped.split(':');
      if (parts.length < 2) return null;
      var h = int.tryParse(parts[0]) ?? -1;
      final m = int.tryParse(parts[1]) ?? -1;
      if (h < 0 || m < 0) return null;
      if (isPm && h < 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    // Case B: 24-hour "HH:mm" or "HH:mm:ss"
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? -1;
    final m = int.tryParse(parts[1]) ?? -1;
    if (h < 0 || m < 0 || h > 23 || m > 59) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }
}