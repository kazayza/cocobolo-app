import 'package:flutter/material.dart';
import '../../services/app_colors.dart';

class NotificationAccessDeniedScreen extends StatelessWidget {
  const NotificationAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعار'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 36,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ليس لديك صلاحية لفتح محتوى هذا الإشعار',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك الرجوع أو التواصل مع مدير النظام لمراجعة صلاحياتك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('رجوع'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
