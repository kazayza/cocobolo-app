import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmFollowUps extends StatelessWidget {
  final List<FollowUpItem> followUps;
  final List<StagnantItem> stagnant;
  final bool isDark;

  const CrmFollowUps({
    super.key,
    required this.followUps,
    required this.stagnant,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (followUps.isEmpty && stagnant.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        if (followUps.isNotEmpty) _buildFollowUpsSection(),
        if (stagnant.isNotEmpty) _buildStagnantSection(),
      ],
    );
  }

  // ══════════════════════════════════════
  // المتابعات القادمة
  // ══════════════════════════════════════
  Widget _buildFollowUpsSection() {
    final sortedFollowUps = List<FollowUpItem>.from(followUps)
      ..sort((a, b) {
        final order = {'overdue': 0, 'today': 1, 'tomorrow': 2, 'upcoming': 3};
        return (order[a.followUpStatus] ?? 4)
            .compareTo(order[b.followUpStatus] ?? 4);
      });

    final overdueCount =
        sortedFollowUps.where((f) => f.followUpStatus == 'overdue').length;
    final todayCount =
        sortedFollowUps.where((f) => f.followUpStatus == 'today').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _buildSectionDecoration(),
        child: Column(
          children: [
            CrmSectionHeader(
              title: 'المتابعات القادمة',
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFFFF9800),
              subtitle:
                  '${followUps.length} متابعة${overdueCount > 0 ? ' • $overdueCount متأخرة' : ''}${todayCount > 0 ? ' • $todayCount اليوم' : ''}',
              isDark: isDark,
            ),

            ...sortedFollowUps.asMap().entries.map((entry) {
              return _buildFollowUpItem(entry.value, entry.key);
            }),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 650.ms);
  }

  // === عنصر متابعة واحد ===
  Widget _buildFollowUpItem(FollowUpItem item, int index) {
    final statusConfig = _getFollowUpStatusConfig(item.followUpStatus);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مؤشر الحالة
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusConfig.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusConfig.color.withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    statusConfig.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // التفاصيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم العميل + badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.clientName,
                            style: GoogleFonts.cairo(
                              color: AppColors.text(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusConfig.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusConfig.color.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            statusConfig.label,
                            style: GoogleFonts.cairo(
                              color: statusConfig.color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // المرحلة والموظف
                    Row(
                      children: [
                        _buildInfoChip(
                          _parseStageColor(item.stageColor),
                          item.stageName,
                        ),
                        if (item.employeeName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              item.employeeName!,
                              style: GoogleFonts.cairo(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    // التاريخ والأيام
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: AppColors.textHint(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.nextFollowUpDate),
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusConfig.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getDaysText(item.daysUntil),
                            style: GoogleFonts.cairo(
                              color: statusConfig.color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // الملاحظات
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 11,
                              color: AppColors.textHint(isDark),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.notes!,
                                style: GoogleFonts.cairo(
                                  color: AppColors.textHint(isDark),
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // أزرار الاتصال والواتساب
              if (item.phone != null && item.phone!.isNotEmpty)
                _buildActionButtons(item.phone!),
            ],
          ),
        ),

        if (index < followUps.length - 1)
          Divider(
            color: AppColors.divider(isDark),
            height: 1,
          ),
      ],
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  // ══════════════════════════════════════
  // الفرص الراكدة
  // ══════════════════════════════════════
  Widget _buildStagnantSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            CrmSectionHeader(
              title: 'فرص راكدة',
              icon: Icons.hourglass_empty_rounded,
              iconColor: const Color(0xFFFF9800),
              subtitle: '${stagnant.length} فرصة بدون تفاعل +7 أيام',
              isDark: isDark,
            ),

            ...stagnant.asMap().entries.map((entry) {
              return _buildStagnantItem(entry.value, entry.key);
            }),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 700.ms);
  }

  // === عنصر فرصة راكدة ===
  Widget _buildStagnantItem(StagnantItem item, int index) {
    final urgencyColor = _getUrgencyColor(item.daysSinceContact);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مؤشر الأيام
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      urgencyColor.withOpacity(0.2),
                      urgencyColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: urgencyColor.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.daysSinceContact}',
                      style: GoogleFonts.cairo(
                        color: urgencyColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      'يوم',
                      style: GoogleFonts.cairo(
                        color: urgencyColor,
                        fontSize: 8,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // التفاصيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم العميل والقيمة
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.clientName,
                            style: GoogleFonts.cairo(
                              color: AppColors.text(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.expectedValue != null &&
                            item.expectedValue! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.gold.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${_formatCurrency(item.expectedValue!)} ج.م',
                              style: GoogleFonts.cairo(
                                color: AppColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // المرحلة والموظف
                    Row(
                      children: [
                        _buildInfoChip(
                          _parseStageColor(item.stageColor),
                          item.stageName,
                        ),
                        if (item.employeeName != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              item.employeeName!,
                              style: GoogleFonts.cairo(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // آخر تفاعل
                    if (item.lastInteractionSummary != null &&
                        item.lastInteractionSummary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 11,
                                color: AppColors.textHint(isDark),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.lastInteractionSummary!,
                                  style: GoogleFonts.cairo(
                                    color: AppColors.textHint(isDark),
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // أزرار الاتصال والواتساب
              if (item.phone != null && item.phone!.isNotEmpty)
                _buildActionButtons(item.phone!),
            ],
          ),
        ),

        if (index < stagnant.length - 1)
          Divider(color: AppColors.divider(isDark), height: 1),
      ],
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  // ══════════════════════════════════════
  // أزرار الاتصال والواتساب
  // ══════════════════════════════════════
  Widget _buildActionButtons(String phone) {
    return Column(
      children: [
        // زرار الاتصال
        GestureDetector(
          onTap: () => _makeCall(phone),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF66BB6A).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: Color(0xFF66BB6A),
              size: 18,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // زرار الواتساب
        GestureDetector(
          onTap: () => _openWhatsApp(phone),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.3),
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/whatsapp.png',
                width: 18,
                height: 18,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 18,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════

  BoxDecoration _buildSectionDecoration() {
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider(isDark)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildInfoChip(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '2$cleanPhone';
    }
    if (!cleanPhone.startsWith('2')) {
      cleanPhone = '2$cleanPhone';
    }

    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getDaysText(int days) {
    if (days < 0) return 'متأخر ${days.abs()} يوم';
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غداً';
    return 'بعد $days أيام';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  _FollowUpStatusConfig _getFollowUpStatusConfig(String status) {
    switch (status) {
      case 'overdue':
        return _FollowUpStatusConfig(
          color: const Color(0xFFEF5350),
          emoji: '🔴',
          label: 'متأخر',
        );
      case 'today':
        return _FollowUpStatusConfig(
          color: const Color(0xFFFFCA28),
          emoji: '🟡',
          label: 'اليوم',
        );
      case 'tomorrow':
        return _FollowUpStatusConfig(
          color: const Color(0xFF42A5F5),
          emoji: '🔵',
          label: 'غداً',
        );
      default:
        return _FollowUpStatusConfig(
          color: const Color(0xFF66BB6A),
          emoji: '🟢',
          label: 'قادم',
        );
    }
  }

  Color _getUrgencyColor(int days) {
    if (days >= 30) return const Color(0xFFEF5350);
    if (days >= 14) return const Color(0xFFFF7043);
    if (days >= 7) return const Color(0xFFFF9800);
    return const Color(0xFFFFCA28);
  }

  Color _parseStageColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF42A5F5);
    try {
      String hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return const Color(0xFF42A5F5);
    }
  }
}

class _FollowUpStatusConfig {
  final Color color;
  final String emoji;
  final String label;

  _FollowUpStatusConfig({
    required this.color,
    required this.emoji,
    required this.label,
  });
}