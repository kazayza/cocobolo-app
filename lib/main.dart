import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

// إعداد الإشعارات المحلية
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// استقبال الإشعارات في الخلفية
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('تم استقبال إشعار في الخلفية: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل الثيم المحفوظ (داكن / فاتح)
  await ThemeService().loadTheme();

  // Firebase والإشعارات للموبايل فقط
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      // تهيئة الإشعارات المحلية
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      // طلب إذن الإشعارات
      await FirebaseMessaging.instance.requestPermission();

      // استقبال الإشعارات في الخلفية
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // استقبال الإشعارات في المقدمة
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'إشعارات مهمة',
                channelDescription: 'قناة الإشعارات المهمة',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });

      // تهيئة خدمة الإشعارات (لو عندك)
      await NotificationService().initialize();

      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeService().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().themeData;

    return MaterialApp(
      title: 'COCOBOLO',
      debugShowCheckedModeBanner: false,

      // رجعنا الاتجاه الافتراضي (بدون فرض RTL)
      theme: theme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(
          theme.textTheme,
        ),
      ),

      home: const LoginScreen(),
    );
  }
}