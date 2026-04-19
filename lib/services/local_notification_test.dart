// lib/services/local_notification_test.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationTest {
  LocalNotificationTest._();

  static final instance = LocalNotificationTest._();
  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Call this to play a simple test notification sound.
  Future<void> showTestNotification() async {
    await _init();

    const androidDetails = AndroidNotificationDetails(
      'test_channel_id',
      'Test Channel',
      channelDescription: 'Untuk ujian bunyi notifikasi',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      9999, // any ID
      'Ujian Notifikasi',
      'Jika anda nampak mesej ini, bunyi sepatutnya keluar.',
      details,
    );
  }
}