import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_colors.dart';

/// شاشة ترحيب بريميوم - COCOBOLO
/// تصميم نيفي + ذهبي فاخر مع لوجو وأنيميشن احترافي
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String _seenKey = 'onboarding_seen';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  final _pageController = PageController();
  late AnimationController _logoPulseController;
  late AnimationController _shimmerController;

  static const _pages = [
    _OnboardingPage(
      title: 'مرحباً بك في COCOBOLO',
      subtitle: 'نظام ERP متكامل لإدارة المبيعات والعملاء والمخزون باحترافية',
      icon: Icons.business_center_rounded,
      accent: AppColors.gold,
    ),
    _OnboardingPage(
      title: 'إدارة العملاء والفرص',
      subtitle: 'تابع عملاءك، الفرص، الأنابيب والمبيعات بدقة من مكان واحد',
      icon: Icons.people_alt_rounded,
      accent: AppColors.gold,
    ),
    _OnboardingPage(
      title: 'المهام والمتابعات الذكية',
      subtitle: 'نظّم مهامك اليومية ومتابعاتك مع تنبيهات فورية وتقارير لحظية',
      icon: Icons.task_alt_rounded,
      accent: AppColors.gold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _logoPulseController.dispose();
    _shimmerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1A2A), // navyDark
              Color(0xFF13273F), // navy
              Color(0xFF1A3352), // navyLight
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // خلفية ديكورية - دوائر ذهبية شفافة
              _buildBackgroundDecor(),

              Column(
                children: [
                  // ── الهيدر: لوجو + تخطي ──
                  _buildHeader(),

                  // ── الصفحات ──
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (_, i) => _buildPage(_pages[i], i),
                    ),
                  ),

                  // ── المؤشر + زر التالي ──
                  _buildBottomSection(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        // دائرة ذهبية علوية
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.06),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 800.ms).scale(delay: 300.ms),
        ),
        // دائرة نيفي سفلية
        Positioned(
          bottom: 80,
          left: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ).animate().fadeIn(delay: 500.ms, duration: 800.ms),
        ),
        // خط ذهبي رفيع
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // اللوجو مع توهج
          Row(
            children: [
              AnimatedBuilder(
                animation: _logoPulseController,
                builder: (_, child) {
                  final pulse = 1.0 + (_logoPulseController.value * 0.08);
                  return Transform.scale(scale: pulse, child: child);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_rounded,
                        color: AppColors.navy,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COCOBOLO',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    'PREMIUM ERP',
                    style: GoogleFonts.cairo(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 700.ms)
              .slideX(begin: -0.15, end: 0, delay: 200.ms, duration: 700.ms, curve: Curves.easeOutCubic),

          // زر تخطي
          GestureDetector(
            onTap: _finish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentPage == _pages.length - 1 ? 'البدء' : 'تخطي',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideX(begin: 0.15, end: 0, delay: 400.ms, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int index) {
    final isActive = _currentPage == index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── أيقونة بريميوم دائرية مع توهج ──
          Stack(
            alignment: Alignment.center,
            children: [
              // توهج خارجي
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.accent.withValues(alpha: 0.08),
                ),
              ).animate(delay: (200 + index * 100).ms).scale(duration: 700.ms, curve: Curves.easeOutBack),

              // حلقة ذهبية متقطعة
              SizedBox(
                width: 122,
                height: 122,
                child: CustomPaint(
                  painter: _DashedCirclePainter(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
              )
                  .animate(delay: (400 + index * 100).ms)
                  .fadeIn(duration: 600.ms)
                  .rotate(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),

              // الحلقة الذهبية المتوهجة
              AnimatedBuilder(
                animation: _logoPulseController,
                builder: (_, child) {
                  final v = _logoPulseController.value;
                  return Container(
                    width: 106 + (v * 6),
                    height: 106 + (v * 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25 + v * 0.15),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.15 + v * 0.1),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    page.icon,
                    size: 48,
                    color: AppColors.navy,
                  ),
                ),
              )
                  .animate(delay: (300 + index * 100).ms)
                  .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 650.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 500.ms),

              // نقطة ذهبية متحركة على الحلقة
              if (isActive)
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (_, __) {
                    final angle = _shimmerController.value * 6.28;
                    return Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: 122,
                        height: 122,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 36),

          // ── العنوان ──
          Text(
            page.title,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: (500 + index * 80).ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.25, end: 0, duration: 550.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 12),

          // خط ذهبي صغير
          Container(
            width: 36,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          )
              .animate(delay: (600 + index * 80).ms)
              .fadeIn(duration: 400.ms)
              .scaleX(begin: 0, end: 1, duration: 500.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // ── الوصف ──
          Text(
            page.subtitle,
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: (650 + index * 80).ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),

          const SizedBox(height: 8),

          // نقاط زخرفية
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withValues(alpha: 0.5))),
              const SizedBox(width: 6),
              Container(width: 18, height: 1.5, decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25))),
            ],
          )
              .animate(delay: (750 + index * 80).ms)
              .fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    final isLast = _currentPage == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // مؤشر الصفحات المطوّر
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final isActive = _currentPage == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

          const SizedBox(height: 28),

          // زر التالي الفاخر
          SizedBox(
            width: double.infinity,
            height: 54,
            child: GestureDetector(
              onTap: _nextPage,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFDBBF74), // gold
                      Color(0xFFE8D49B), // goldLight
                      Color(0xFFDBBF74),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // shimmer effect
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (_, __) {
                        return Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Transform.translate(
                              offset: Offset((_shimmerController.value * 320) - 80, 0),
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // المحتوى
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLast ? 'البدء الآن' : 'التالي',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.navy.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, delay: 600.ms, duration: 600.ms, curve: Curves.easeOutCubic)
              .shimmer(delay: 1200.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.25)),

          const SizedBox(height: 12),

          // نص صغير تحت الزر
          if (!isLast)
            Text(
              'اسحب للمتابعة أو اضغط التالي',
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 500.ms)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, size: 12, color: AppColors.gold.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  'جاهز للانطلاق مع COCOBOLO',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}

/// حلقة متقطعة ذهبية
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const dashCount = 24;
    const dashAngle = 0.18; // طول كل شرطة بالراديان
    const gapAngle = (6.28 - dashCount * dashAngle) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final start = i * (dashAngle + gapAngle) - 1.57; // ابدأ من الأعلى
      final sweep = dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
