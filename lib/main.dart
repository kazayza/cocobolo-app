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
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
//import 'screens/home_screen.dart';
import 'features/home/home_screen_v2.dart';
import 'services/notification_service.dart';
import 'services/profile_avatar_service.dart';
import 'services/theme_service.dart';
import 'services/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/add_expense_screen.dart';
import 'screens/products_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/opportunity_detail_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/lead_detail_screen.dart';
import 'core/notifications/notification_navigator.dart';
import 'core/navigation/app_routes.dart';
import 'core/navigation/app_navigator.dart';
import 'providers/auth_provider.dart';
import 'core/auth/session_service.dart';
import 'core/network/api_client.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // لو الرسالة تحتوي notification فالنظام يعرضها تلقائياً في الخلفية؛
  // عرض Local ثانية كان يسبب تكرار نفس الإشعار.
  if (message.notification != null) return;

  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings: settings);
    await plugin.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: message.data['title']?.toString() ?? 'إشعار جديد',
      body: (message.data['message'] ?? message.data['body'] ?? '').toString(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'إشعارات مهمة',
          channelDescription: 'قناة الإشعارات المهمة',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  } catch (e) {
    debugPrint('Background notification error: $e');
  }
}

// ✅ فتح الشاشة الصحيحة عند الضغط على الإشعار
Future<void> _handleNotificationTap(String? payload) async {
  // Blazor FormName is source of truth — Flutter only maps via NotificationNavigator
  await NotificationNavigator.openFromPayload(navigatorKey, payload);
}

// ✅ تسجيل / تحديث توكن الجهاز في الخادم
Future<void> _registerDeviceToken() async {
  if (!SessionService.instance.hasToken) return;
  await NotificationService().registerCurrentDeviceToken();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().loadTheme();
  await ProfileAvatarService().load();
  await SessionService.instance.initialize();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await NotificationService().initialize(onTap: _handleNotificationTap);
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground: النظام لا يعرض Notification تلقائياً، فنستخدم Local Notification واحدة.
      FirebaseMessaging.onMessage.listen((message) {
        NotificationService().showRemoteMessage(message);
      });

      // Local notification فتح التطبيق من حالة Terminated.
      final localLaunchPayload = NotificationService().launchPayload;
      if (localLaunchPayload != null && localLaunchPayload.isNotEmpty) {
        await NotificationNavigator.queuePayload(localLaunchPayload);
      }

      // FCM notification فتح التطبيق من حالة Terminated.
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        await NotificationNavigator.queuePayload(jsonEncode(initialMessage.data));
      }

      // التطبيق كان في الخلفية وتم فتحه بالنقر على FCM.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (message.data.isNotEmpty) {
          _handleNotificationTap(jsonEncode(message.data));
        }
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        _registerDeviceToken();
      });
      await _registerDeviceToken();
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _splashDone = false; // السبلاش خلص أنيميشن
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;
  int _userId = 0;
  String _username = '';
  String _fullName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeService().addListener(_onThemeChanged);
    _checkLoginStatus();
    _loadOnboardingStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeService().removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        SessionService.instance.hasToken) {
      _registerDeviceToken();
    }
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _schedulePendingNotification() {
    if (!_isLoggedIn || !_splashDone) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationNavigator.flushPending(navigatorKey);
    });
  }

  // استعادة الجلسة من Token؛ لا نعيد إرسال كلمة المرور ولا نخزنها.
  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (isLoggedIn && rememberMe && SessionService.instance.hasToken) {
        final response = await ApiClient.instance.get('/api/auth/me');
        final data = ApiClient.instance.decode(response);
        final user = Map<String, dynamic>.from(data['user'] as Map);

        PermissionService().initialize(
          user: user,
          permissions: Map<String, dynamic>.from(
            (data['permissions'] ?? const {}) as Map,
          ),
          claims: (data['claims'] ?? const []) as List<dynamic>,
        );

        AuthProvider().login(
          userId: user['UserID'] as int,
          username: user['Username'] as String,
          fullName: user['FullName'] as String? ?? '',
          email: user['Email'] as String?,
          employeeId: user['employeeID'] as int?,
          role: user['Role'] as String? ?? '',
          token: SessionService.instance.accessToken!,
        );

        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _userId = user['UserID'] as int;
            _username = user['Username'] as String;
            _fullName = user['FullName'] as String? ?? '';
          });
          _schedulePendingNotification();
        }
        if (!kIsWeb) await _registerDeviceToken();
      } else if (isLoggedIn) {
        await SessionService.instance.clear();
      }
    } on ApiException catch (e) {
      debugPrint('Session restore failed: ${e.message}');
      if (e.statusCode == 401) await SessionService.instance.clear();
    } catch (e) {
      // لا نفتح بيانات حساسة Offline بدون صلاحيات موثقة.
      debugPrint('Session restore connection error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _loadOnboardingStatus() async {
    final seen = await OnboardingScreen.hasSeen();
    if (mounted) {
      setState(() => _hasSeenOnboarding = seen);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── إعادة البناء تلقائياً عند تغيير الثيم (ليلي/نهاري) ──
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final themeService = ThemeService();

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'COCOBOLO',
          debugShowCheckedModeBanner: false,
          // ── الثيمات: نهاري + ليلي + وضع تلقائي حسب الاختيار ──
          theme: themeService.lightTheme.copyWith(
            textTheme: GoogleFonts.cairoTextTheme(
              themeService.lightTheme.textTheme,
            ),
          ),
          darkTheme: themeService.darkTheme.copyWith(
            textTheme: GoogleFonts.cairoTextTheme(
              themeService.darkTheme.textTheme,
            ),
          ),
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          // ═══ إضافة اللغة العربية ═══
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          // ═══ إجبار العربية → اتجاه RTL في كل الشاشات ═══
          locale: const Locale('ar'),
          // ═══════════════════════════
          home: _isChecking || !_splashDone
              ? SplashScreen(
                  onFinished: () {
                    if (!mounted) return;
                    setState(() => _splashDone = true);
                    _schedulePendingNotification();
                  },
                )
              : _isLoggedIn
              ? const HomeScreenV2()
              : _hasSeenOnboarding
              ? const LoginScreen()
              : const OnboardingScreen(),
          routes: AppRoutes.all,
        );
      },
    );
  }


}
