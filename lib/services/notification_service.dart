import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/network/api_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  String? _currentUsername;
  int _lastNotificationId = 0;
  bool _initialized = false;
  String? _launchPayload;

  Future<void> Function(String? payload)? onNotificationTap;
  String? get launchPayload => _launchPayload;

  Future<void> initialize({
    required Future<void> Function(String? payload) onTap,
  }) async {
    if (_initialized) {
      onNotificationTap = onTap;
      return;
    }
    onNotificationTap = onTap;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) async {
        await onNotificationTap?.call(response.payload);
      },
    );

    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _launchPayload = launch?.notificationResponse?.payload;
    }

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'إشعارات مهمة',
      description: 'إشعارات النظام المهمة',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await android?.createNotificationChannel(channel);
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<bool> registerCurrentDeviceToken({int maxAttempts = 3}) async {
    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // نسجل التوكن رغم ذلك؛ عند تفعيل الإذن لاحقاً لا يحتاج الخادم لتحديث آخر.
        debugPrint(
            'Notification permission is denied; token will still be registered');
      }

      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token == null || token.isEmpty) {
            throw StateError('Firebase لم يُرجع توكن للجهاز');
          }

          final response = await ApiClient.instance.post(
            '/api/auth/save-token',
            body: {'fcmToken': token},
          );
          final data = ApiClient.instance.decode(response);
          if (data is Map && data['success'] == true) {
            debugPrint('FCM token registered successfully');
            return true;
          }
          throw StateError('الخادم لم يؤكد تسجيل توكن الإشعارات');
        } catch (error) {
          lastError = error;
          if (attempt < maxAttempts) {
            await Future<void>.delayed(Duration(seconds: attempt * 2));
          }
        }
      }

      debugPrint('FCM token registration failed after retries: $lastError');
      return false;
    } catch (error) {
      debugPrint('FCM token registration error: $error');
      return false;
    }
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    final routedId = int.tryParse('${message.data['notificationId'] ?? ''}');
    if (routedId != null && routedId > _lastNotificationId) {
      _lastNotificationId = routedId;
    }
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'إشعار جديد';
    final body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        '';
    await showLocalNotification(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
  }

  void startPolling(
    String username, {
    Duration interval = const Duration(seconds: 30),
  }) {
    _currentUsername = username;
    stopPolling();
    _checkForNewNotifications();
    _pollingTimer =
        Timer.periodic(interval, (_) => _checkForNewNotifications());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// فحص إشعارات تأخر التسليم وإظهارها كإشعارات محلية.
  /// يُستخدم للتذكير بالطلبات المتأخرة عن موعد التسليم.
  Future<void> checkDeliveryNotifications() async {
    if (_currentUsername == null) return;
    try {
      final response = await ApiClient.instance.get(
        '/api/delivery/stats',
        forceRefresh: true,
      );
      final decoded = ApiClient.instance.decode(response);
      final envelope = Map<String, dynamic>.from(decoded as Map);
      final data = envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : envelope;
      final stats = data['stats'] is Map
          ? Map<String, dynamic>.from(data['stats'] as Map)
          : data;
      final rawCount = stats['Overdue'] ?? stats['overdue'] ?? 0;
      final count =
          rawCount is num ? rawCount.toInt() : int.tryParse('$rawCount') ?? 0;
      if (count <= 0) return;

      await showLocalNotification(
        id: 900001,
        title: 'تذكير بتوصيلات متأخرة',
        body: 'يوجد $count طلب في انتظار التسليم أو متأخر عن الموعد.',
        payload: jsonEncode(
            {'routeVersion': '2', 'formName': 'frm_DeliveryTracking'}),
      );
    } catch (e) {
      debugPrint('Delivery notification check error: $e');
    }
  }

  Future<void> _checkForNewNotifications() async {
    if (_currentUsername == null) return;
    try {
      final response =
          await ApiClient.instance.get('/api/notifications/unread');
      final data = ApiClient.instance.decode(response);
      final notifications = (data['notifications'] as List?) ?? const [];

      for (final raw in notifications) {
        final notification = Map<String, dynamic>.from(raw as Map);
        final notificationId = notification['NotificationID'] is int
            ? notification['NotificationID'] as int
            : int.tryParse('${notification['NotificationID']}') ?? 0;
        if (notificationId <= _lastNotificationId) continue;

        await showLocalNotification(
          id: notificationId,
          title: notification['Title'] ?? 'إشعار جديد',
          body: notification['Message'] ?? '',
          payload: jsonEncode({
            'routeVersion': '2',
            'notificationId': notificationId,
            'relatedTable': notification['RelatedTable'],
            'relatedId': notification['RelatedID'],
            'formName': notification['FormName'],
          }),
        );
        _lastNotificationId = notificationId;
      }
    } catch (e) {
      debugPrint('Notification polling error: $e');
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'إشعارات مهمة',
        channelDescription: 'إشعارات النظام المهمة',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFDBBF74),
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<int> getUnreadCount(String _username) async {
    try {
      final response =
          await ApiClient.instance.get('/api/notifications/unread');
      final data = ApiClient.instance.decode(response);
      return data['count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

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
      final response = await ApiClient.instance.post(
        '/api/notifications',
        body: {
          'title': title,
          'message': message,
          'recipientUser': recipientUser,
          'relatedTable': relatedTable,
          'relatedId': relatedId,
          'formName': formName,
          'createdBy': createdBy,
        },
      );
      final data = ApiClient.instance.decode(response);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
