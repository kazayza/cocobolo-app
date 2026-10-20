import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/theme_service.dart';

/// شاشة ترحيب تعرض للمستخدمين الجدد مرة واحدة فقط.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String _seenKey = 'onboarding_seen';

  /// التحقق مما إذا كان المستخدم قد شاهد الشاشة من قبل.
  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  /// وضع علامة على أن المستخدم شاهد الشاشة.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final _pageController = PageController();

  static const _pages = [
    _OnboardingPage(
      title: 'مرحباً بك في COCOBOLO',
      subtitle: 'نظام إدارة متكامل لعلاقات العملاء والمبيعات',
      icon: Icons.business_rounded,
      color: AppColors.navy,
    ),
    _OnboardingPage(
      title: 'إدارة العملاء والفرص',
      subtitle: 'تابع عملاءك، الفرص، والأنابيب 판매 بسهولة',
      icon: Icons.people_rounded,
      color: AppColors.success,
    ),
    _OnboardingPage(
      title: 'المهام والمتابعات',
      subtitle: 'نظم مهامك اليومية ومتابعات العملاء في مكان واحد',
      icon: Icons.task_rounded,
      color: AppColors.warning,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // تخطي في الزاوية العلوية اليمنى
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  _currentPage == _pages.length - 1 ? 'البدء' : 'تخطي',
                  style: AppTextStyles.labelMedium(isDark).copyWith(
                    color: AppColors.gold,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildPage(_pages[i], isDark),
              ),
            ),

            // مؤشر الصفحات + زر التالي
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.gold
                              : AppColors.textSecondary(isDark)
                                  .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'البدء الآن'
                                : 'التالي',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 56,
              color: page.color,
            ),
          ).animate().scale(delay: 200.ms, duration: 600.ms),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: AppTextStyles.displayLarge(isDark),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: AppTextStyles.bodyLarge(isDark).copyWith(
              color: AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
