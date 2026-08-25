import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/theme_service.dart';
import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'profile_avatar.dart';

/// ترويسة فخمة بهوية COCOBOLO:
/// تدرج Navy عميق + لمسات ذهبية + تاريخ عربي + جرس إشعارات متوهج + صورة رمزية بحلقة ذهبية
class HomeHeroHeader extends StatelessWidget {
  final VoidCallback onNotificationPressed;
  final VoidCallback onMenuPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onThemeToggle;
  final VoidCallback onAccentPressed;
  final VoidCallback onAvatarTap;
  const HomeHeroHeader({
    super.key,
    required this.onNotificationPressed,
    required this.onMenuPressed,
    required this.onSettingsPressed,
    required this.onSearchPressed,
    required this.onThemeToggle,
    required this.onAccentPressed,
    required this.onAvatarTap,
  });

  static const List<String> _weekdays = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  static const List<String> _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'تصبح على خير';
  }

  String _dateText(DateTime now) {
    final weekday = _weekdays[now.weekday % 7];
    final month = _months[now.month - 1];
    return '$weekday، $month ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    // إعادة البناء الفورية عند تغيير اللون أو الثيم
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final auth = AuthProvider();

    // عرض الاسم الكامل (FullName) أولاً — ولو مش موجود نستخدم username
    final displayName = (auth.fullName != null && auth.fullName!.trim().isNotEmpty)
        ? auth.fullName!
        : (auth.username ?? 'المستخدم');
    final username = auth.username ?? '';

    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [HomeAccent.navyDark, HomeAccent.navy, HomeAccent.navyLight],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: HomeAccent.navyDark.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // توهج ذهبي زخرفي
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeAccent.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeAccent.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // منطقة التحية/الاسم — الضغط عليها يفتح القائمة الجانبية
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onMenuPressed,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _greeting(now),
                                    style: TextStyle(
                                      color: HomeAccent.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateText(now),
                                style: const TextStyle(
                                  color: Color(0xB3FFFFFF),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Consumer<HomeProvider>(
                    builder: (context, provider, _) {
                      return _BellButton(
                        count: provider.unreadCount,
                        onPressed: onNotificationPressed,
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  // صورة المستخدم — الضغط عليها يفتح الإعدادات
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: ProfileAvatar(
                      initial: displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'U',
                      size: 58,
                      goldRing: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── شريط البحث الشامل + تبديل الثيم ──────────
              Row(
                children: [
                  Expanded(child: _SearchBar(onTap: onSearchPressed)),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return _HeaderIconButton(
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                        onPressed: onThemeToggle,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // زر تغيير الألوان
                  _HeaderIconButton(
                    icon: Icons.palette_rounded,
                    tooltip: 'تغيير الألوان',
                    onPressed: onAccentPressed,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // فاصل ذهبي متلاشي الأطراف
              Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HomeAccent.accent.withValues(alpha: 0.0),
                      HomeAccent.accent,
                      HomeAccent.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شريط بحث شامل — يفتح شاشة البحث عند الضغط
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: HomeAccent.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحث في كل الأقسام...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر دائري شفاف في الترويسة الداكنة
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(9),
        minimumSize: const Size(40, 40),
      ),
      icon: Icon(icon, size: 21),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _BellButton({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(9),
        minimumSize: const Size(40, 40),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 21),
          if (count > 0)
            Positioned(
              left: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
