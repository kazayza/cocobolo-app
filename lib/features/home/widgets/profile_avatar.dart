import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/profile_avatar_service.dart';
import 'home_accent.dart';

/// ─────────────────────────────────────────────────────────────
///  صورة المستخدم — قابلة لإعادة الاستخدام في كل الأماكن
///  - لو في صورة محفوظة → تعرضها
///  - مفيش صورة → تعرض الحرف الأول (fallback)
///  - لو الصورة اتلفت أو اتحذفت → ترجع للحرف تلقائياً
///  - `goldRing`: حلقة ذهبية (للهوم) / `circle`: شكل دائري
/// ─────────────────────────────────────────────────────────────
class ProfileAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final double borderRadius;
  final bool goldRing;
  final bool circle;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.initial,
    this.size = 44,
    this.borderRadius = 14,
    this.goldRing = false,
    this.circle = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder → يتحدث تلقائياً عند تغيير الصورة من أي مكان
    return ListenableBuilder(
      listenable: ProfileAvatarService(),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final path = ProfileAvatarService().imagePath;
    final hasImage = path != null && File(path).existsSync();

    // ── حلقة ذهبية (هوم) ─────────────────────────────────
    if (goldRing) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HomeAccent.gold, HomeAccent.goldDark],
          ),
        ),
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: hasImage
                ? Image.file(
                    File(path!),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _letterAvatar(context, circular: true),
                  )
                : _letterAvatar(context, circular: true),
          ),
        ),
      );
    }

    // ── صورة ─────────────────────────────────────────────
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(circle ? size / 2 : borderRadius),
        child: Image.file(
          File(path!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterAvatar(context),
        ),
      );
    }

    // ── حرف (fallback) ───────────────────────────────────
    return _letterAvatar(context);
  }

  Widget _letterAvatar(BuildContext context, {bool circular = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor ?? HomeAccent.navyLight, HomeAccent.navy],
        ),
        borderRadius: BorderRadius.circular(circular ? size / 2 : borderRadius),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: HomeAccent.gold,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
