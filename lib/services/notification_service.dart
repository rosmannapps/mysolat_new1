// lib/services/notification_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'prefs_service.dart';
import 'azan_audio_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _prefKeyEnabled = 'notifications_enabled';
  static const String _channelId = 'prayer_times_channel_v3';
  static const String _channelName = 'Notifikasi Waktu Solat';
  static const String _malaysiaTz = 'Asia/Kuala_Lumpur';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_malaysiaTz));

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentSound: true,
      defaultPresentAlert: true,
      defaultPresentBanner: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        AzanAudioService.instance.stop();
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();

    }

    _initialized = true;
  }

  Future<bool> getNotificationsEnabled() async {
    return PrefsService.instance.getBool(_prefKeyEnabled) ?? false;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await PrefsService.instance.setBool(_prefKeyEnabled, value);
    await _ensureInitialized();
    if (!value) await _plugin.cancelAll();
  }

  NotificationDetails _buildDetails() {
    final vibrationPattern = Int64List.fromList([0, 1000, 200, 1000, 200, 1000]);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Pemberitahuan apabila masuk waktu solat.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      enableLights: true,
      fullScreenIntent: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> schedulePrayerNotifications({
    required String subuh,
    required String zohor,
    required String asar,
    required String maghrib,
    required String isyak,
    required String zoneName,
  }) async {
    final enabled = await getNotificationsEnabled();
    if (!enabled) return;

    await _ensureInitialized();

    // Cancel existing
    for (int id = 1; id <= 5; id++) {
      await _plugin.cancel(id);
    }

    final prayers = {
      1: ('Subuh', subuh),
      2: ('Zohor', zohor),
      3: ('Asar', asar),
      4: ('Maghrib', maghrib),
      5: ('Isyak', isyak),
    };

    final now = tz.TZDateTime.now(tz.local);

    for (final entry in prayers.entries) {
      final id = entry.key;
      final name = entry.value.$1;
      final timeStr = entry.value.$2;

      final scheduled = _parseToTZDateTime(timeStr, now);
      if (scheduled == null) continue;
      if (scheduled.isBefore(now)) continue;

      try {
        await _plugin.zonedSchedule(
          id,
          '🕌 Masuk Waktu $name',
          'Waktu $name telah masuk — $zoneName',
          scheduled,
          _buildDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('❌ Failed to schedule $name: $e');
      }
    }
  }

  tz.TZDateTime? _parseToTZDateTime(String timeStr, tz.TZDateTime reference) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      int hour = 0;
      int minute = 0;

      if (cleaned.contains('AM') || cleaned.contains('PM')) {
        final isPm = cleaned.contains('PM');
        final timePart = cleaned
            .replaceAll('AM', '')
            .replaceAll('PM', '')
            .trim();
        final parts = timePart.split(':');
        hour = int.parse(parts[0].trim());
        minute = int.parse(parts[1].trim().split(' ')[0]);
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        final parts = cleaned.split(':');
        hour = int.parse(parts[0].trim());
        minute = int.parse(parts[1].trim());
      }

      return tz.TZDateTime(
        tz.local,
        reference.year,
        reference.month,
        reference.day,
        hour,
        minute,
        0,
      );
    } catch (e) {
      debugPrint('Failed to parse time: $timeStr — $e');
      return null;
    }
  }

  Future<void> showSimpleNotification({
    int id = 0,
    String title = 'Waktu Solat',
    String body = 'Ini contoh notifikasi.',
  }) async {
    await _ensureInitialized();
    final enabled = await getNotificationsEnabled();
    if (!enabled) return;
    await _plugin.show(id, title, body, _buildDetails());
  }

  Future<void> showTestNotification() async {
    await _ensureInitialized();
    final enabled = await getNotificationsEnabled();
    if (!enabled) return;
    await _plugin.show(
      999,
      'Uji Bunyi & Getaran',
      'Jika anda dengar bunyi dan rasa getaran, notifikasi berfungsi.',
      _buildDetails(),
    );
  }
}
