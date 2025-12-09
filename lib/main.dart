import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة خدمة الإشعارات
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COCOBOLO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        textTheme: GoogleFonts.cairoTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}