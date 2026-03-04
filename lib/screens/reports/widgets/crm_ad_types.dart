import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmAdTypes extends StatefulWidget {
  final List<AdTypeItem> adTypes;
  final bool isDark;

  const CrmAdTypes({
    super.key,
    required this.adTypes,
    required this.isDark,
  });

  @override
  State<CrmAdTypes> createState() => _CrmAdTypesState();
}

class _CrmAdTypesState extends State<CrmAdTypes> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.adTypes.isEmpty) return const SizedBox.shrink();

    final totalOpportunities =
        widget.adTypes.fold<int>(0, (sum, a) => sum + a.total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(widget.isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            CrmSectionHeader(
              title: 'أنواع الإعلانات',
              icon: Icons.campaign_rounded,
              iconColor: const Color(0xFFFF7043),
              subtitle:
                  '$totalOpportunities فرصة من ${widget.adTypes.length} حملات',
              isDark: widget.isDark,
            ),

            // === الجدول ===
            _buildHeader(),
            const SizedBox(height: 8),

            ...widget.adTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildAdTypeRow(item, totalOpportunities, index);
            }),

            const SizedBox(height: 12),

            // === تفاصيل الحملة المختارة ===
            if (_selectedIndex != null)
              _buildSelectedDetails(widget.adTypes[_selectedIndex!]),

            if (_selectedIndex != null) const SizedBox(height: 12),

            // === أفضل حملة ===
            _buildBestCampaign(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 350.ms);
  }

  // === Header الجدول ===
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'الحملة',
              style: GoogleFonts.cairo(
                color: AppColors.textHint(widget.isDark),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _headerCell('الفرص'),
          _headerCell('مكسبة'),
          _headerCell('تحويل'),
          _headerCell('إيراد'),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Expanded(
      flex: 2,
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: AppColors.textHint(widget.isDark),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // === صف حملة واحدة ===
  Widget _buildAdTypeRow(AdTypeItem item, int total, int index) {
    final percentage = total > 0 ? (item.total / total) : 0.0;
    final barColor = _getAdTypeColor(index);
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 8 : 4, vertical: isSelected ? 8 : 6),
        decoration: BoxDecoration(
          color: isSelected
              ? barColor.withOpacity(widget.isDark ? 0.1 : 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: barColor.withOpacity(0.3))
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // اسم الحملة مع indicator
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.cairo(
                            color: isSelected
                                ? barColor
                                : AppColors.text(widget.isDark),
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // الفرص
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.total}',
                    style: GoogleFonts.cairo(
                      color: AppColors.text(widget.isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // مكسبة
                Expanded(
                  flex: 2,
                  child: Text(
                    '${item.won}',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF66BB6A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // تحويل
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getConversionColor(item.conversionRate)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.conversionRate.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                        color: _getConversionColor(item.conversionRate),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // إيراد
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(item.actualRevenue),
                    style: GoogleFonts.cairo(
                      color: item.actualRevenue > 0
                          ? const Color(0xFF66BB6A)
                          : AppColors.textHint(widget.isDark),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // بار النسبة
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage.clamp(0.02, 1.0),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!isSelected && index < widget.adTypes.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Divider(
                  color: AppColors.divider(widget.isDark),
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 400.ms);
  }

  // === تفاصيل الحملة المختارة ===
  Widget _buildSelectedDetails(AdTypeItem item) {
    final barColor = _getAdTypeColor(
        widget.adTypes.indexWhere((a) => a.adTypeId == item.adTypeId));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            barColor.withOpacity(widget.isDark ? 0.12 : 0.06),
            barColor.withOpacity(widget.isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem('❌', 'خاسرة', '${item.lost}', const Color(0xFFEF5350)),
          _buildDetailDivider(),
          _buildDetailItem(
              '💰', 'متوسط الصفقة',
              item.won > 0 ? _formatCurrency(item.actualRevenue / item.won) : '0',
              const Color(0xFF42A5F5)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
        );
  }

  Widget _buildDetailItem(
      String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(widget.isDark),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.divider(widget.isDark),
    );
  }

  // === أفضل حملة ===
  Widget _buildBestCampaign() {
    final best = widget.adTypes.reduce(
      (a, b) => a.conversionRate > b.conversionRate ? a : b,
    );
    final highestRevenue = widget.adTypes.reduce(
      (a, b) => a.actualRevenue > b.actualRevenue ? a : b,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'أفضل تحويل: ',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(widget.isDark),
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: Text(
                  '${best.name} (${best.conversionRate.toStringAsFixed(0)}%)',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF66BB6A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (highestRevenue.actualRevenue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'أعلى إيراد: ',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(widget.isDark),
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${highestRevenue.name} (${_formatCurrency(highestRevenue.actualRevenue)} ج.م)',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFF42A5F5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // === Helpers ===
  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    if (amount == 0) return '-';
    return amount.toStringAsFixed(0);
  }

  Color _getAdTypeColor(int index) {
    const colors = [
      Color(0xFFFF7043),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
      Color(0xFF5C6BC0),
      Color(0xFF8D6E63),
    ];
    return colors[index % colors.length];
  }

  Color _getConversionColor(double rate) {
    if (rate >= 50) return const Color(0xFF66BB6A);
    if (rate >= 30) return const Color(0xFFFFCA28);
    return const Color(0xFFEF5350);
  }
}