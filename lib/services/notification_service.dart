// lib/services/notification_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _prefKeyEnabled = 'notifications_enabled';
  static const String _channelId = 'prayer_times_channel_v2';
  static const String _channelName = 'Notifikasi Waktu Solat';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // BASIC INITIALISATION -----------------------------------------------
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

    // ANDROID 13+ RUNTIME PERMISSION -------------------------------------
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  // ----------------------------------------------------------------------
  // PREFERENCES: ON / OFF
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
      // User turned OFF: cancel all scheduled + shown notifications
      await _plugin.cancelAll();
    }
  }

  // ----------------------------------------------------------------------
  // COMMON NOTIFICATION DETAILS (sound + vibration)
  // ----------------------------------------------------------------------

  NotificationDetails _buildPlatformDetails({String? soundName}) {
    final vibrationPattern = Int64List.fromList([0, 600, 250, 600]);

    // if soundName is null, use default notification sound
    final androidSound = soundName == null
        ? null
        : RawResourceAndroidNotificationSound(soundName);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Pemberitahuan apabila masuk waktu solat.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: androidSound,      // <-- use custom sound if not null
      enableVibration: true,
      vibrationPattern: vibrationPattern,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,       // iOS: will use default unless you set a custom one
      presentBadge: false,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  // ----------------------------------------------------------------------
  // SIMPLE NOTIFICATION (USED INTERNALLY)
  // ----------------------------------------------------------------------

  Future<void> showSimpleNotification({
    int id = 0,
    String title = 'Waktu Solat',
    String body = 'Ini contoh notifikasi.',
  }) async {
    await _ensureInitialized();

    final enabled = await getNotificationsEnabled();
    if (!enabled) return;

    await _plugin.show(
      id,
      title,
      body,
      _buildPlatformDetails(),
    );
  }

  // ----------------------------------------------------------------------
  // TEST NOTIFICATION: sound + vibration
  // ----------------------------------------------------------------------

  Future<void> showTestNotification({String? soundName}) async {
    await _ensureInitialized();

    final enabled = await getNotificationsEnabled();
    if (!enabled) return;

    await _plugin.show(
      999,
      'Uji Bunyi & Getaran',
      'Jika anda dengar bunyi dan rasa getaran, notifikasi berfungsi.',
      _buildPlatformDetails(soundName: soundName),
    );
  }

// ----------------------------------------------------------------------
// (Next step: schedule(DateTime) for setiap waktu solat)
// ----------------------------------------------------------------------
}