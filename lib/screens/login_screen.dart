import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../constants.dart';
import 'home_screen.dart';
import '../services/permission_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  // Animation Controllers
  late AnimationController _backgroundController;
  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _logoController.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  // ✅ دالة تسجيل الدخول المعدّلة مع الصلاحيات
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
        
        // ✅ حفظ الصلاحيات في الـ PermissionService
        PermissionService().initialize(
          user: data['user'] as Map<String, dynamic>,
          permissions: (data['permissions'] ?? {}) as Map<String, dynamic>,
        );
        
        // طباعة الصلاحيات للتأكد (يمكن حذفها لاحقاً)
        PermissionService().printPermissions();

        // Success Animation
        _showSuccessDialog();
        
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          // إغلاق الـ Dialog
          Navigator.pop(context);
          
          // الانتقال للشاشة الرئيسية مع بيانات المستخدم
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
        }
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFFFFD700),
                size: 80,
              )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text(
                'تم تسجيل الدخول بنجاح!',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // ✅ عرض اسم المستخدم
              Text(
                'مرحباً ${_username.text}',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
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
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF1A0F08),
                    const Color(0xFF2D1810),
                    _backgroundController.value,
                  )!,
                  const Color(0xFF0A0A0A),
                  Color.lerp(
                    const Color(0xFF0F0805),
                    const Color(0xFF1A1005),
                    _backgroundController.value,
                  )!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildAnimatedLogo(),
                    const SizedBox(height: 60),
                    _buildLoginCard(),
                    const SizedBox(height: 40),
                    _buildLoginButton(),
                    const SizedBox(height: 30),
                    _buildFooterText(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _logoController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(
                      0.2 + (_logoController.value * 0.3),
                    ),
                    blurRadius: 30 + (_logoController.value * 20),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        )
            .animate()
            .fadeIn(duration: 800.ms)
            .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
        
        const SizedBox(height: 30),
        
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFFA500),
              Color(0xFFFFD700),
            ],
          ).createShader(bounds),
          child: Text(
            'COCOBOLO',
            style: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 800.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        
        const SizedBox(height: 15),
        
        AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Luxury Furniture Since 1960',
              textStyle: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                color: Colors.white70,
                letterSpacing: 3,
                fontStyle: FontStyle.italic,
              ),
              speed: const Duration(milliseconds: 100),
            ),
          ],
          isRepeatingAnimation: false,
        ),
        
        const SizedBox(height: 10),
        
        Container(
          width: 100,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFFFFD700),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        )
            .animate()
            .fadeIn(delay: 1000.ms)
            .scaleX(begin: 0, end: 1, delay: 1000.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'تسجيل الدخول',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          _buildTextField(
            controller: _username,
            label: 'اسم المستخدم',
            icon: Icons.person_outline,
            delay: 600,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _password,
            label: 'كلمة المرور',
            icon: Icons.lock_outline,
            isPassword: true,
            delay: 800,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 800.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    int delay = 0,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFFFD700).withOpacity(0.7),
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isPassword ? 'كلمة المرور مطلوبة' : 'اسم المستخدم مطلوب';
        }
        return null;
      },
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 600.ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'دخول',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 600.ms)
        .slideY(begin: 0.3, end: 0)
        .then()
        .shimmer(delay: 500.ms, duration: 1500.ms);
  }

  Widget _buildFooterText() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1, color: Colors.white24),
            const SizedBox(width: 15),
            Text(
              '✦',
              style: TextStyle(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 15),
            Container(width: 40, height: 1, color: Colors.white24),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'نظام إدارة متكامل',
          style: GoogleFonts.cairo(
            color: Colors.white38,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'ERP System v2.0',
          style: GoogleFonts.roboto(
            color: Colors.white24,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 1200.ms, duration: 800.ms);
  }
}