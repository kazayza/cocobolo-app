import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/widgets/home_accent.dart';
import '../services/theme_service.dart';

/// ─────────────────────────────────────────────────────────────
///  Splash Screen احترافي — هوية COCOBOLO
///  - تدرج Navy عميق + توهج ذهبي متحرك
///  - اللوجو يدخل بتدرج + حلقة ذهبية تدور
///  - نص COCOBOLO بيظهر حرف بحرف + تحت "تصميم وتطوير"
/// ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _ringRotation;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _subtitleFade;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // اللوجو: يكبر ويظهر
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // الحلقة الذهبية: تدور
    _ringRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // النص: يطلع من تحت
    _textSlide = Tween<double>(begin: 0.6, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.55, curve: Curves.easeIn),
      ),
    );

    // السطر الفرعي: يظهر أخيراً
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.85, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // بعد الانتهاء → نستدعي onFinished (أو ننتظر 3 ثواني)
    _timer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted && widget.onFinished != null) {
        widget.onFinished!();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A2A),
      body: Stack(
        children: [
          // ── التدرج الأساسي ────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1A2A),
                  Color(0xFF13273F),
                  Color(0xFF0D1A2A),
                ],
              ),
            ),
          ),

          // ── توهجات ذهبية زخرفية ───────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeAccent.gold.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeAccent.gold.withValues(alpha: 0.04),
              ),
            ),
          ),

          // ── المحتوى ────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اللوجو + الحلقة الذهبية الدوارة
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // الحلقة الذهبية الدوارة
                            Transform.rotate(
                              angle: _ringRotation.value * 6.2832,
                              child: Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: HomeAccent.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 2,
                                  ),
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.transparent,
                                      HomeAccent.gold.withValues(alpha: 0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // اللوجو
                            Container(
                              width: 150,
                              height: 150,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    HomeAccent.navyDark,
                                    HomeAccent.navyLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(36),
                                border: Border.all(
                                  color: HomeAccent.gold.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeAccent.gold.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.diamond_rounded,
                                    color: HomeAccent.gold,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // اسم الشركة — يظهر بحركة
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textFade.value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * _textSlide.value),
                        child: Column(
                          children: [
                            const Text(
                              'COCOBOLO',
                              style: TextStyle(
                                color: HomeAccent.gold,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 120,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    HomeAccent.gold.withValues(alpha: 0),
                                    HomeAccent.gold,
                                    HomeAccent.gold.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Luxury Furniture & Design',
                              style: TextStyle(
                                color: Color(0xFFB8C4D4),
                                fontSize: 13,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 50),

                // التحميل + السطر الأخير
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _subtitleFade.value,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: HomeAccent.gold.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '© 2026 COCOBOLO — جميع الحقوق محفوظة',
                            style: TextStyle(
                              color: Color(0xFF5A6B80),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'تصميم وتطوير: أحمد الرفاعى',
                            style: TextStyle(
                              color: Color(0xFF5A6B80),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
