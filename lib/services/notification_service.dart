import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  Timer? _pollingTimer;
  String? _currentUsername;
  int _lastNotificationId = 0;
  
  // Callback عند الضغط على الإشعار
  Function(String? payload)? onNotificationTap;

  // تهيئة الخدمة
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );
    
    // طلب الإذن للأندرويد 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  // بدء الفحص الدوري
  void startPolling(String username, {Duration interval = const Duration(seconds: 30)}) {
    _currentUsername = username;
    
    // إيقاف أي timer قديم
    stopPolling();
    
    // فحص فوري
    _checkForNewNotifications();
    
    // فحص دوري
    _pollingTimer = Timer.periodic(interval, (_) {
      _checkForNewNotifications();
    });
    
    print('🔔 بدء فحص الإشعارات لـ $username');
  }

  // إيقاف الفحص
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    print('🔕 إيقاف فحص الإشعارات');
  }

  // فحص الإشعارات الجديدة
  Future<void> _checkForNewNotifications() async {
    if (_currentUsername == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread?username=$_currentUsername'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List;
        
        // عرض إشعار محلي لكل إشعار جديد
        for (var notification in notifications) {
          final notificationId = notification['NotificationID'] as int;
          
          // تجنب عرض نفس الإشعار مرتين
          if (notificationId > _lastNotificationId) {
            await _showLocalNotification(
              id: notificationId,
              title: notification['Title'] ?? 'إشعار جديد',
              body: notification['Message'] ?? '',
              payload: jsonEncode({
                'notificationId': notificationId,
                'relatedTable': notification['RelatedTable'],
                'relatedId': notification['RelatedID'],
                'formName': notification['FormName'],
              }),
            );
            _lastNotificationId = notificationId;
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في فحص الإشعارات: $e');
    }
  }

  // عرض إشعار محلي
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'cocobolo_notifications',
      'إشعارات COCOBOLO',
      channelDescription: 'إشعارات النظام',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFD700),
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // جلب عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread?username=$username'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
    } catch (e) {
      print('❌ خطأ في جلب عدد الإشعارات: $e');
    }
    return 0;
  }

  // إرسال إشعار
  Future<bool> sendNotification({
    required String title,
    required String message,
    required String recipientUser,
    required String createdBy,
    String? relatedTable,
    int? relatedId,
    String? formName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'message': message,
          'recipientUser': recipientUser,
          'relatedTable': relatedTable,
          'relatedId': relatedId,
          'formName': formName,
          'createdBy': createdBy,
        }),
      );
      
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } catch (e) {
      print('❌ خطأ في إرسال الإشعار: $e');
      return false;
    }
  }
}