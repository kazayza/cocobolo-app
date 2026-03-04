import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/app_colors.dart';

class CrmSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;
  final bool isDark;

  const CrmSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.gold).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: AppColors.text(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}