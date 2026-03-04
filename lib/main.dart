import 'package:http/http.dart' as http;
import 'constants.dart';
import 'services/permission_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/add_expense_screen.dart';
import 'screens/products_screen.dart';
import 'screens/notifications_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print('تم استقبال إشعار في الخلفية: ${message.messageId}');
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().loadTheme();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              final formName = data['formName'];
              final id = data['relatedId'];

              final prefs = await SharedPreferences.getInstance();
              final savedUsername = prefs.getString('username') ?? 'User';
              final savedUserId = prefs.getInt('userId') ?? 0;

              if (formName == 'frm_Expenses') {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(
                      username: savedUsername,
                      expenseId: id,
                    ),
                  ),
                );
              } else if (formName == 'frm_Products' || formName == 'frm_ProductPricing') {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => ProductsScreen(
                      userId: savedUserId,
                      username: savedUsername,
                    ),
                  ),
                );
              } else {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(
                      userId: savedUserId,
                      username: savedUsername,
                    ),
                  ),
                );
              }
            } catch (e) {
              print('Error parsing notification payload: $e');
            }
          }
        },
      );

      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
            payload: jsonEncode(message.data),
          );
        }
      });

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
  bool _isChecking = true;
  bool _isLoggedIn = false;
  int _userId = 0;
  String _username = '';
  String _fullName = '';

  @override
  void initState() {
    super.initState();
    ThemeService().addListener(_onThemeChanged);
    _checkLoginStatus();
  }

  @override
  void dispose() {
    ThemeService().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  // ✅ تشييك حالة الـ Login
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (isLoggedIn && rememberMe) {
        final userId = prefs.getInt('userId') ?? 0;
        final username = prefs.getString('username') ?? '';
        final fullName = prefs.getString('fullName') ?? '';
        final savedPassword = prefs.getString('saved_password') ?? '';

        if (userId > 0 && username.isNotEmpty && savedPassword.isNotEmpty) {
          // ✅ نعمل Login فعلي عشان نجيب الصلاحيات
          try {
            final response = await http.post(
              Uri.parse('$baseUrl/api/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': username,
                'password': savedPassword,
              }),
            );

            final data = jsonDecode(response.body);

            if (response.statusCode == 200 && data['success'] == true) {
              // ✅ حفظ الصلاحيات
              PermissionService().initialize(
                user: data['user'] as Map<String, dynamic>,
                permissions: (data['permissions'] ?? {}) as Map<String, dynamic>,
              );

              setState(() {
                _isLoggedIn = true;
                _userId = data['user']['UserID'] as int;
                _username = data['user']['Username'] as String;
                _fullName = data['user']['FullName'] as String? ?? '';
              });
            } else {
              // ✅ لو الباسورد اتغير أو فيه مشكلة → يروح Login
              await prefs.setBool('is_logged_in', false);
            }
          } catch (e) {
            // ✅ لو مفيش نت → يفتح عادي ببيانات محفوظة بدون صلاحيات
            print('⚠️ مفيش اتصال - فتح بدون صلاحيات: $e');
            setState(() {
              _isLoggedIn = true;
              _userId = userId;
              _username = username;
              _fullName = fullName;
            });
          }
        }
      }
    } catch (e) {
      print('❌ خطأ في تشييك الـ Login: $e');
    }

    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService().themeData;

   return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'COCOBOLO',
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(theme.textTheme),
      ),
      // ═══ إضافة اللغة العربية ═══
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      //locale: const Locale('ar'),
      // ═══════════════════════════
      home: _isChecking
          ? _buildSplashScreen()
          : _isLoggedIn
              ? HomeScreen(
                  userId: _userId,
                  username: _username,
                  fullName: _fullName,
                  
                )
              : const LoginScreen(),
    );
  }

  // ✅ شاشة انتظار أثناء التشييك
  Widget _buildSplashScreen() {
  final isDark = ThemeService().isDarkMode;
  return Scaffold(
    backgroundColor: AppColors.background(isDark),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // اللوجو
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // اسم التطبيق
          Text(
            'COCOBOLO',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
              letterSpacing: 4,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Loading
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'جاري التحميل...',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    ),
  );
}
}