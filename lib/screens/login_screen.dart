import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../constants.dart';
import 'home_screen.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../services/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    ThemeService().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService().removeListener(_onThemeChanged);
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  // تحميل بيانات "تذكرني"
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedUsername != null && savedPassword != null) {
      setState(() {
        _username.text = savedUsername;
        _password.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  // حفظ بيانات "تذكرني"
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_username', _username.text.trim());
      await prefs.setString('saved_password', _password.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username.text.trim(),
          'password': _password.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // حفظ "تذكرني"
        await _saveCredentials();

        // FCM Token للموبايل فقط
        if (!kIsWeb) {
          try {
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await http.post(
                Uri.parse('$baseUrl/api/users/save-token'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'userId': data['user']['UserID'],
                  'fcmToken': token,
                }),
              );
            }
          } catch (e) {
            print('⚠️ خطأ في FCM Token: $e');
          }
        }

        // حفظ صلاحيات المستخدم
        PermissionService().initialize(
          user: data['user'] as Map<String, dynamic>,
          permissions: (data['permissions'] ?? {}) as Map<String, dynamic>,
        );

        _showSuccessDialog();

        await Future.delayed(const Duration(milliseconds: 1200));

        if (!mounted) return;
        Navigator.pop(context); // يقفل الـ Dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userId: data['user']['UserID'] as int,
              username: data['user']['Username'] as String,
              fullName: data['user']['FullName'] as String?,
            ),
          ),
        );
      } else {
        _showErrorSnackBar(data['message'] ?? 'بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      _showErrorSnackBar('لا يوجد اتصال بالإنترنت');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    final isDark = ThemeService().isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.gold,
                  size: 50,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text(
                'تم تسجيل الدخول بنجاح!',
                style: GoogleFonts.cairo(
                  color: AppColors.text(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'مرحباً ${_username.text}',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.loginGradient(isDark),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      _buildThemeToggle(isDark),
                      const SizedBox(height: 30),
                      _buildLogo(isDark),
                      const SizedBox(height: 40),
                      _buildLoginCard(isDark),
                      const SizedBox(height: 25),
                      _buildLoginButton(isDark),
                      const SizedBox(height: 25),
                      _buildFooterText(isDark),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDark) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        decoration: BoxDecoration(
          color: (isDark ? AppColors.navy : Colors.white).withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gold.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () => ThemeService().toggleTheme(),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: AppColors.gold,
          ),
          tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.diamond,
                        color: AppColors.gold,
                        size: 60,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'COCOBOLO',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 800.ms)
            .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 25),
        Text(
          'COCOBOLO',
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.gold : AppColors.navy,
            letterSpacing: 6,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
        const SizedBox(height: 8),
        Text(
          'Luxury Furniture Since 1960',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 16,
            color: AppColors.textSecondary(isDark),
            letterSpacing: 2,
            fontStyle: FontStyle.italic,
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 800.ms),
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.gold,
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        )
            .animate()
            .fadeIn(delay: 800.ms, duration: 600.ms)
            .scaleX(begin: 0, end: 1, duration: 600.ms),
      ],
    );
  }

  Widget _buildLoginCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: isDark ? AppColors.navy.withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.gold.withOpacity(isDark ? 0.3 : 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 1,
                color: AppColors.gold.withOpacity(0.5),
              ),
              const SizedBox(width: 12),
              Text(
                'تسجيل الدخول',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.gold : AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 30,
                height: 1,
                color: AppColors.gold.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _buildTextField(
            controller: _username,
            label: 'اسم المستخدم',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _password,
            label: 'كلمة المرور',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildRememberMe(isDark),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 800.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: GoogleFonts.cairo(
        color: AppColors.text(isDark),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(
          color: AppColors.textHint(isDark),
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? AppColors.gold : AppColors.navy,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: (isDark ? AppColors.gold : AppColors.navy)
                      .withOpacity(0.7),
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
        filled: true,
        fillColor: isDark
            ? AppColors.navyDark.withOpacity(0.6)
            : AppColors.lightInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isDark ? AppColors.gold : AppColors.navy,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isPassword ? 'كلمة المرور مطلوبة' : 'اسم المستخدم مطلوب';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMe(bool isDark) {
    return Row(
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) =>
                setState(() => _rememberMe = value ?? false),
            activeColor: isDark ? AppColors.gold : AppColors.navy,
            checkColor: isDark ? AppColors.navy : Colors.white,
            side: BorderSide(
              color: AppColors.textHint(isDark),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Text(
            'تذكرني',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.gold, AppColors.goldLight]
              : [AppColors.navy, AppColors.navyLight],
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDark ? AppColors.gold : AppColors.navy).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.navy : Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'تسجيل الدخول',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.navy : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? AppColors.navy : Colors.white,
                    size: 22,
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 700.ms, duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildFooterText(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 35,
              height: 1,
              color: AppColors.divider(isDark),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.diamond_outlined,
              color: AppColors.gold.withOpacity(0.6),
              size: 16,
            ),
            const SizedBox(width: 12),
            Container(
              width: 35,
              height: 1,
              color: AppColors.divider(isDark),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          'نظام إدارة متكامل',
          style: GoogleFonts.cairo(
            color: AppColors.textHint(isDark),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ERP System v2.0',
          style: GoogleFonts.roboto(
            color: AppColors.textHint(isDark).withOpacity(0.7),
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 900.ms, duration: 800.ms);
  }
}