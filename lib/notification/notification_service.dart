import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  
  final FlutterLocalNotificationsPlugin notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  NotificationService._internal();
  
  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await notificationsPlugin.initialize(initSettings);
  }
  
  Future<void> scheduleWateringReminder(int id, String plantName, DateTime reminderTime) async {
    await notificationsPlugin.zonedSchedule(
      id,
      '浇水提醒',
      '您的$plantName需要浇水了！',
      tz.TZDateTime.from(reminderTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'watering_channel',
          '浇水提醒',
          channelDescription: '植物浇水提醒通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  Future<void> cancelReminder(int id) async {
    await notificationsPlugin.cancel(id);
  }
}