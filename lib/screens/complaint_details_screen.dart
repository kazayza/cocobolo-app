import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/complaint_model.dart';
import '../services/complaints_service.dart';
import '../services/theme_service.dart';
import '../services/app_colors.dart';
import 'add_complaint_screen.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final int complaintId;
  final int userId;
  final String username;

  const ComplaintDetailsScreen({
    super.key,
    required this.complaintId,
    required this.userId,
    required this.username,
  });

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  bool _isLoading = true;
  ComplaintModel? _complaint;
  List<FollowUpModel> _followUps = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===================================
  // تحميل البيانات
  // ===================================
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final complaint = await ComplaintsService.getComplaintById(widget.complaintId);
      if (complaint != null) {
        final followUps = await ComplaintsService.getFollowUps(widget.complaintId);
        setState(() {
          _complaint = complaint;
          _followUps = followUps;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'الشكوى غير موجودة';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل البيانات';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? _buildLoading(isDark)
          : _error != null
              ? _buildError(isDark)
              : _buildBody(isDark),
    );
  }

  // ===================================
  // AppBar
  // ===================================
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.navy : Colors.white,
      elevation: 0,
      title: Text(
        'تفاصيل الشكوى',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : AppColors.navy,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_complaint != null) ...[
          // زر التعديل
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? AppColors.gold : AppColors.navy,
            ),
            onPressed: _editComplaint,
          ),
          // زر الحذف
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
            ),
            onPressed: _deleteComplaint,
          ),
        ],
      ],
    );
  }

  // ===================================
  // Loading
  // ===================================
  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل البيانات...',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // Error
  // ===================================
  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // Body
  // ===================================
  Widget _buildBody(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.gold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // كارت الحالة والأولوية
            _buildStatusCard(isDark),
            const SizedBox(height: 16),

            // بيانات العميل
            _buildClientCard(isDark),
            const SizedBox(height: 16),

            // تفاصيل الشكوى
            _buildDetailsCard(isDark),
            const SizedBox(height: 16),

            // معلومات التصعيد (لو مصعدة)
            if (_complaint!.escalated) ...[
              _buildEscalationCard(isDark),
              const SizedBox(height: 16),
            ],

            // المتابعات
            _buildFollowUpsSection(isDark),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            _buildActionButtons(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ===================================
  // كارت الحالة والأولوية
  // ===================================
  Widget _buildStatusCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPriorityColor(_complaint!.priority).withOpacity(0.8),
            _getPriorityColor(_complaint!.priority),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getPriorityColor(_complaint!.priority).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الأولوية والحالة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الأولوية
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _complaint!.priorityText,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // الحالة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _complaint!.statusText,
                  style: GoogleFonts.cairo(
                    color: _getStatusColor(_complaint!.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // العنوان
          Text(
            _complaint!.subject,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // التاريخ والنوع
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                _formatDate(_complaint!.complaintDate),
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.category, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _complaint!.complaintType ?? 'غير محدد',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================
  // كارت بيانات العميل
  // ===================================
  Widget _buildClientCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'بيانات العميل',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // اسم العميل
          _buildInfoRow(
            isDark: isDark,
            icon: Icons.badge_outlined,
            label: 'الاسم',
            value: _complaint!.clientName ?? 'غير محدد',
          ),
          const SizedBox(height: 12),

          // رقم الهاتف
          _buildInfoRow(
            isDark: isDark,
            icon: Icons.phone_outlined,
            label: 'الهاتف',
            value: _complaint!.phone ?? 'غير محدد',
            isPhone: true,
          ),

          // رقم الهاتف 2
          if (_complaint!.phone2 != null && _complaint!.phone2!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.phone_outlined,
              label: 'هاتف 2',
              value: _complaint!.phone2!,
              isPhone: true,
            ),
          ],

          // العنوان
          if (_complaint!.address != null && _complaint!.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: _complaint!.address!,
            ),
          ],
        ],
      ),
    );
  }

  // ===================================
  // كارت تفاصيل الشكوى
  // ===================================
  Widget _buildDetailsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'تفاصيل الشكوى',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // التفاصيل
          Text(
            _complaint!.details,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.text(isDark),
              height: 1.8,
            ),
          ),
          const SizedBox(height: 16),

          // المسؤول
          if (_complaint!.assignedToName != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.support_agent,
              label: 'المسؤول',
              value: _complaint!.assignedToName!,
            ),
          ],

          // منشئ الشكوى
          if (_complaint!.createdBy != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.person_add_outlined,
              label: 'أنشأها',
              value: _complaint!.createdBy!,
            ),
          ],

          // الحل (لو الشكوى محلولة)
if (_complaint!.status == 4 && _complaint!.solution != null) ...[
  const SizedBox(height: 16),
  const Divider(height: 1),
  const SizedBox(height: 16),
  Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ),
      const SizedBox(width: 12),
      Text(
        'الحل',
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    ],
  ),
  const SizedBox(height: 12),
  Text(
    _complaint!.solution!,
    style: GoogleFonts.cairo(
      fontSize: 14,
      color: AppColors.text(isDark),
      height: 1.8,
    ),
  ),
  if (_complaint!.solvedDate != null) ...[
    const SizedBox(height: 8),
    Row(
      children: [
        Icon(Icons.calendar_today, size: 14, color: Colors.green),
        const SizedBox(width: 6),
        Text(
          'تاريخ الحل: ${_formatDate(_complaint!.solvedDate)}',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.green,
          ),
        ),
      ],
    ),
  ],
  if (_complaint!.satisfactionLevel != null) ...[
    const SizedBox(height: 8),
    Row(
      children: [
        Icon(Icons.star, size: 14, color: Colors.amber),
        const SizedBox(width: 6),
        Text(
          'رضا العميل: ${_getSatisfactionText(_complaint!.satisfactionLevel!)}',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.amber.shade700,
          ),
        ),
      ],
    ),
  ],
],
        ],
      ),
    );
  }

  // ===================================
  // كارت التصعيد
  // ===================================
  Widget _buildEscalationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات التصعيد',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // مصعدة إلى
          if (_complaint!.escalatedToName != null)
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.person,
              label: 'مصعدة إلى',
              value: _complaint!.escalatedToName!,
              valueColor: Colors.purple,
            ),

          // مصعدة بواسطة
          if (_complaint!.escalatedByName != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.person_outline,
              label: 'بواسطة',
              value: _complaint!.escalatedByName!,
            ),
          ],

          // تاريخ التصعيد
          if (_complaint!.escalatedAt != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              isDark: isDark,
              icon: Icons.access_time,
              label: 'تاريخ التصعيد',
              value: _formatDateTime(_complaint!.escalatedAt!),
            ),
          ],

          // سبب التصعيد
          if (_complaint!.escalationReason != null) ...[
            const SizedBox(height: 12),
            Text(
              'السبب:',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _complaint!.escalationReason!,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.text(isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================================
  // قسم المتابعات
  // ===================================
  Widget _buildFollowUpsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان وزر الإضافة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'المتابعات',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_followUps.length}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showAddFollowUpSheet,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // قائمة المتابعات
          if (_followUps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: AppColors.textHint(isDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد متابعات بعد',
                      style: GoogleFonts.cairo(
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _followUps.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                return _buildFollowUpItem(_followUps[index], isDark);
              },
            ),
        ],
      ),
    );
  }

  // ===================================
  // عنصر المتابعة
  // ===================================
  Widget _buildFollowUpItem(FollowUpModel followUp, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // التاريخ والموظف
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(followUp.followUpDate),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
            Text(
              followUp.followUpByName ?? 'غير محدد',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // الملاحظات
        Text(
          followUp.notes,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.text(isDark),
            height: 1.6,
          ),
        ),

        // الإجراء المتخذ
        if (followUp.actionTaken != null && followUp.actionTaken!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    followUp.actionTaken!,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // موعد المتابعة القادمة
        if (followUp.nextFollowUpDate != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                'المتابعة القادمة: ${_formatDate(followUp.nextFollowUpDate)}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===================================
  // أزرار الإجراءات
  // ===================================
  // ===================================
// أزرار الإجراءات
// ===================================
Widget _buildActionButtons(bool isDark) {
  // لو الشكوى محلولة أو مرفوضة، نعرض رسالة بس
  if (_complaint!.status == 4 || _complaint!.status == 5) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _complaint!.status == 4 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _complaint!.status == 4 ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _complaint!.status == 4 ? Icons.check_circle : Icons.cancel,
            color: _complaint!.status == 4 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            _complaint!.status == 4 ? 'تم حل الشكوى' : 'تم رفض الشكوى',
            style: GoogleFonts.cairo(
              color: _complaint!.status == 4 ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    children: [
      // الصف الأول: تغيير الحالة + التصعيد
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showChangeStatusSheet,
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: Text(
                'تغيير الحالة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _complaint!.escalated ? null : _showEscalateSheet,
              icon: const Icon(Icons.arrow_upward, size: 20),
              label: Text(
                _complaint!.escalated ? 'مصعدة' : 'تصعيد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _complaint!.escalated
                    ? Colors.grey
                    : Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      
      // الصف الثاني: حل الشكوى
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showSolveSheet,
          icon: const Icon(Icons.check_circle, size: 20),
          label: Text(
            'حل الشكوى',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  );
}

  // ===================================
  // Info Row Helper
  // ===================================
  Widget _buildInfoRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    bool isPhone = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary(isDark)),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: valueColor ?? AppColors.text(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // Bottom Sheets
  // ===================================

  // إضافة متابعة
  void _showAddFollowUpSheet() {
    final notesController = TextEditingController();
    final actionController = TextEditingController();
    DateTime? nextFollowUpDate;
    final isDark = ThemeService().isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // العنوان
                Text(
                  'إضافة متابعة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 20),

                // ملاحظات المتابعة
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: GoogleFonts.cairo(color: AppColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات المتابعة *',
                    labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // الإجراء المتخذ
                TextField(
                  controller: actionController,
                  style: GoogleFonts.cairo(color: AppColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'الإجراء المتخذ (اختياري)',
                    labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // موعد المتابعة القادمة
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => nextFollowUpDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: AppColors.textSecondary(isDark)),
                        const SizedBox(width: 12),
                        Text(
                          nextFollowUpDate != null
                              ? _formatDate(nextFollowUpDate)
                              : 'موعد المتابعة القادمة (اختياري)',
                          style: GoogleFonts.cairo(
                            color: nextFollowUpDate != null
                                ? AppColors.text(isDark)
                                : AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // زر الحفظ
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (notesController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'يرجى إدخال ملاحظات المتابعة',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        await ComplaintsService.createFollowUp(
                          complaintId: widget.complaintId,
                          followUpBy: widget.userId,
                          notes: notesController.text,
                          actionTaken: actionController.text.isNotEmpty
                              ? actionController.text
                              : null,
                          nextFollowUpDate: nextFollowUpDate,
                        );

                        Navigator.pop(context);
                        _loadData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم إضافة المتابعة بنجاح',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'فشل في إضافة المتابعة',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'حفظ المتابعة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // تغيير الحالة
  void _showChangeStatusSheet() {
    final isDark = ThemeService().isDarkMode;
    int selectedStatus = _complaint!.status;

    final statuses = [
      {'id': 1, 'name': 'جديدة', 'color': Colors.blue},
      {'id': 2, 'name': 'قيد الحل', 'color': Colors.orange},
      {'id': 3, 'name': 'انتظار', 'color': Colors.amber},
      {'id': 4, 'name': 'محلولة', 'color': Colors.green},
      {'id': 5, 'name': 'مرفوضة', 'color': Colors.red},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // العنوان
                Text(
                  'تغيير حالة الشكوى',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 20),

                // قائمة الحالات
                ...statuses.map((status) => ListTile(
                  onTap: () {
                    setSheetState(() => selectedStatus = status['id'] as int);
                  },
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: status['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    status['name'] as String,
                    style: GoogleFonts.cairo(
                      color: AppColors.text(isDark),
                      fontWeight: selectedStatus == status['id']
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: selectedStatus == status['id']
                      ? Icon(Icons.check_circle, color: status['color'] as Color)
                      : null,
                )),
                const SizedBox(height: 20),

                // زر الحفظ
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ComplaintsService.updateComplaint(
                          widget.complaintId,
                          {'status': selectedStatus},
                        );

                        Navigator.pop(context);
                        _loadData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تغيير الحالة بنجاح',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'فشل في تغيير الحالة',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'حفظ',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // التصعيد
  void _showEscalateSheet() {
    final reasonController = TextEditingController();
    final isDark = ThemeService().isDarkMode;
    // TODO: جلب قائمة الموظفين من الـ API
    int? selectedEmployee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // العنوان
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.purple, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'تصعيد الشكوى',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TODO: Dropdown لاختيار الموظف
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppColors.textSecondary(isDark)),
                      const SizedBox(width: 12),
                      Text(
                        'اختر الموظف للتصعيد إليه *',
                        style: GoogleFonts.cairo(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // سبب التصعيد
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: GoogleFonts.cairo(color: AppColors.text(isDark)),
                  decoration: InputDecoration(
                    labelText: 'سبب التصعيد *',
                    labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // زر التصعيد
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (reasonController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'يرجى إدخال سبب التصعيد',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // TODO: تنفيذ التصعيد بعد اختيار الموظف
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_upward),
                    label: Text(
                      'تأكيد التصعيد',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ===================================
// حل الشكوى
// ===================================
void _showSolveSheet() {
  final isDark = ThemeService().isDarkMode;
  final solutionController = TextEditingController();
  int selectedSatisfaction = 3; // افتراضي: متوسط

  final satisfactionLevels = [
    {'id': 1, 'name': 'غير راضي', 'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.red},
    {'id': 2, 'name': 'راضي جزئياً', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.orange},
    {'id': 3, 'name': 'متوسط', 'icon': Icons.sentiment_neutral, 'color': Colors.amber},
    {'id': 4, 'name': 'راضي', 'icon': Icons.sentiment_satisfied, 'color': Colors.lightGreen},
    {'id': 5, 'name': 'راضي جداً', 'icon': Icons.sentiment_very_satisfied, 'color': Colors.green},
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'حل الشكوى',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // الحل
              Text(
                'الحل *',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(isDark),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: solutionController,
                maxLines: 4,
                style: GoogleFonts.cairo(color: AppColors.text(isDark)),
                decoration: InputDecoration(
                  hintText: 'اكتب الحل الذي تم تقديمه للعميل...',
                  hintStyle: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
                  filled: true,
                  fillColor: AppColors.inputFill(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // تقييم رضا العميل
              Text(
                'تقييم رضا العميل',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: satisfactionLevels.map((level) {
                  final isSelected = selectedSatisfaction == level['id'];
                  return GestureDetector(
                    onTap: () {
                      setSheetState(() => selectedSatisfaction = level['id'] as int);
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (level['color'] as Color).withOpacity(0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? level['color'] as Color
                                  : AppColors.divider(isDark),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            level['icon'] as IconData,
                            color: level['color'] as Color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          level['name'] as String,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: isSelected
                                ? level['color'] as Color
                                : AppColors.textSecondary(isDark),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (solutionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'يرجى كتابة الحل',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await ComplaintsService.updateComplaint(
                        widget.complaintId,
                        {
                          'status': 4, // محلولة
                          'solution': solutionController.text.trim(),
                          'solvedDate': DateTime.now().toIso8601String(),
                          'satisfactionLevel': selectedSatisfaction,
                        },
                      );

                      Navigator.pop(context);
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم حل الشكوى بنجاح',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'فشل في حفظ الحل',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: Text(
                    'حفظ وإغلاق الشكوى',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ===================================
  // Actions
  // ===================================

  // تعديل الشكوى
  void _editComplaint() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddComplaintScreen(
          userId: widget.userId,
          username: widget.username,
          complaint: _complaint,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  // حذف الشكوى
  void _deleteComplaint() {
    final isDark = ThemeService().isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              'حذف الشكوى',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.text(isDark),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الشكوى؟',
          style: GoogleFonts.cairo(color: AppColors.text(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ComplaintsService.deleteComplaint(widget.complaintId);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Return to list

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الشكوى بنجاح',
                      style: GoogleFonts.cairo(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'فشل في حذف الشكوى',
                      style: GoogleFonts.cairo(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  // ===================================
  // Helper Functions
  // ===================================
  Color _getStatusColor(int status) {
    switch (status) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.green;
      case 5: return Colors.red;
      case 6: return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return Colors.red.shade700;
      case 2: return Colors.orange;
      case 3: return Colors.amber.shade700;
      case 4: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
// ===================================
// نص رضا العميل
// ===================================
String _getSatisfactionText(int level) {
  switch (level) {
    case 1: return 'غير راضي 😞';
    case 2: return 'راضي جزئياً 😕';
    case 3: return 'متوسط 😐';
    case 4: return 'راضي 🙂';
    case 5: return 'راضي جداً 😄';
    default: return 'غير محدد';
  }
}
}