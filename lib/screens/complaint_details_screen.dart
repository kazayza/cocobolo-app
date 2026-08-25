import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<ComplaintAttachmentModel> _attachments = [];
  bool _isUploading = false;
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
        final results = await Future.wait([
          ComplaintsService.getFollowUps(widget.complaintId),
          ComplaintsService.getAttachments(widget.complaintId),
        ]);
        setState(() {
          _complaint = complaint;
          _followUps = results[0] as List<FollowUpModel>;
          _attachments = results[1] as List<ComplaintAttachmentModel>;
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

            // 📎 المرفقات (صور / مستندات)
            _buildAttachmentsSection(isDark),
            const SizedBox(height: 16),

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
  // ===================================
  // 📎 سكشن المرفقات (مطابق لبلازور)
  // ===================================
  Widget _buildAttachmentsSection(bool isDark) {
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
          // العنوان وزر الرفع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.attach_file, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'المرفقات',
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
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_attachments.length}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // زر الرفع (زي بلازور: صور + PDF + Word + Excel)
              _isUploading
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'رفع...',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : IconButton(
                      onPressed: _showAttachmentPicker,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.upload, color: Colors.white, size: 18),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 16),

          // شبكة المرفقات
          if (_attachments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.note_add_outlined,
                      size: 48,
                      color: AppColors.textHint(isDark),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد مرفقات',
                      style: GoogleFonts.cairo(
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                return _buildAttachmentCard(_attachments[index], isDark);
              },
            ),
        ],
      ),
    );
  }

  // ===================================
  // كارت المرفق (صورة أو مستند)
  // ===================================
  Widget _buildAttachmentCard(ComplaintAttachmentModel att, bool isDark) {
    if (att.isImage) {
      // 🖼️ صورة
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAttachment(att),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
            color: Colors.black12,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                ComplaintsService.attachmentUrl(att.attachmentId),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Container(
                    color: Colors.black12,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textHint(isDark),
                      size: 32,
                    ),
                  );
                },
              ),
              // شريط سفلي: الاسم + الحذف
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          att.originalFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteAttachment(att),
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'حذف المرفق',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 📄 مستند (PDF / Word / Excel)
    final (icon, color) = _docIcon(att.mimeType);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openAttachment(att),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider(isDark)),
          color: color.withOpacity(isDark ? 0.12 : 0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 26),
                const Spacer(),
                // فتح
                IconButton(
                  onPressed: () => _openAttachment(att),
                  icon: Icon(Icons.open_in_new, color: AppColors.textHint(isDark), size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'فتح الملف',
                ),
                // حذف
                IconButton(
                  onPressed: () => _deleteAttachment(att),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'حذف المرفق',
                ),
              ],
            ),
            const Spacer(),
            Text(
              att.originalFileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              att.fileSizeFormatted,
              style: GoogleFonts.cairo(
                fontSize: 10,
                color: AppColors.textHint(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // أيقونة ولون حسب نوع المستند (زي بلازور)
  (IconData, Color) _docIcon(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('pdf')) return (Icons.picture_as_pdf, Colors.redAccent);
    if (m.contains('word') || m.contains('doc')) return (Icons.description, Colors.blue);
    if (m.contains('excel') || m.contains('sheet') || m.contains('xls')) {
      return (Icons.table_chart, Colors.green);
    }
    if (m.contains('powerpoint') || m.contains('ppt')) {
      return (Icons.slideshow, Colors.orange);
    }
    return (Icons.insert_drive_file, AppColors.textHint(true));
  }

  // ===================================
  // اختيار المرفق (صورة من المعرض أو ملف)
  // ===================================
  Future<void> _showAttachmentPicker() async {
    final isDark = ThemeService().isDarkMode;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة مرفق',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.photo_outlined,
                      color: Colors.blue,
                      label: 'صورة من المعرض',
                      onTap: () => Navigator.pop(context, 'image'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerOption(
                      icon: Icons.upload_file,
                      color: Colors.orange,
                      label: 'ملف (PDF / Word / Excel)',
                      onTap: () => Navigator.pop(context, 'file'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الحد الأقصى للحجم: 10 ميجا',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textHint(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'image') {
      await _pickAndUploadImage();
    } else if (choice == 'file') {
      await _pickAndUploadFile();
    }
  }

  Widget _pickerOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // رفع صورة من المعرض
  // ===================================
  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      await _uploadAttachment(
        fileName: picked.name,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      _showSnack('فشل اختيار الصورة: $e', isError: true);
    }
  }

  // ===================================
  // رفع ملف (PDF / Word / Excel) — نفس صيغ بلازور
  // ===================================
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();

      final mime = _mimeFromName(file.name);
      await _uploadAttachment(
        fileName: file.name,
        bytes: bytes,
        mimeType: mime,
      );
    } catch (e) {
      _showSnack('فشل اختيار الملف: $e', isError: true);
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'application/octet-stream';
  }

  // ===================================
  // التنفيذ الفعلي للرفع
  // ===================================
  Future<void> _uploadAttachment({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      _showSnack('الحجم يتجاوز 10 ميجا — المرفق لم يُرفع', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final id = await ComplaintsService.uploadAttachment(
        widget.complaintId,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        uploadedByUserId: widget.userId,
      );
      if (id != null) {
        final refreshed = await ComplaintsService.getAttachments(widget.complaintId);
        if (mounted) {
          setState(() {
            _attachments = refreshed;
            _isUploading = false;
          });
          _showSnack('تم رفع المرفق بنجاح ✅');
        }
      } else {
        if (mounted) setState(() => _isUploading = false);
        _showSnack('فشل رفع المرفق — تحقق من الصيغة والحجم', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      _showSnack('فشل رفع المرفق: $e', isError: true);
    }
  }

  // ===================================
  // فتح المرفق (صورة = عارض كامل / مستند = تحميل وفتح)
  // ===================================
  Future<void> _openAttachment(ComplaintAttachmentModel att) async {
    final url = ComplaintsService.attachmentUrl(att.attachmentId);

    if (att.isImage) {
      // 🖼️ عارض صور ملء الشاشة
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _FullImageScreen(
            url: url,
            title: att.originalFileName,
          ),
        ),
      );
      return;
    }

    // 📄 تحميل المستند وفتحه (open_filex) — لو فشل نفتحه في المتصفح
    _showSnack('جاري تحميل الملف...');
    try {
      final dir = await getTemporaryDirectory();
      final ext = att.fileName.contains('.')
          ? att.fileName.substring(att.fileName.lastIndexOf('.'))
          : '';
      final filePath = '${dir.path}/complaint_${att.attachmentId}$ext';

      final file = File(filePath);
      if (await file.exists()) await file.delete();

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await file.writeAsBytes(bytes);
      client.close();

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok) _showSnack('لا يوجد تطبيق لفتح هذا النوع من الملفات', isError: true);
      }
    } catch (e) {
      _showSnack('فشل تحميل الملف: $e', isError: true);
    }
  }

  // ===================================
  // حذف مرفق (بتأكيد زي بلازور)
  // ===================================
  Future<void> _deleteAttachment(ComplaintAttachmentModel att) async {
    final isDark = ThemeService().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف المرفق؟',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.text(isDark)),
        ),
        content: Text(
          'هل تريد حذف «${att.originalFileName}»؟',
          style: GoogleFonts.cairo(color: AppColors.text(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textHint(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ComplaintsService.deleteAttachment(widget.complaintId, att.attachmentId);
    if (ok) {
      final refreshed = await ComplaintsService.getAttachments(widget.complaintId);
      if (mounted) {
        setState(() => _attachments = refreshed);
        _showSnack('تم حذف المرفق ✅');
      }
    } else {
      _showSnack('فشل حذف المرفق', isError: true);
    }
  }

  // SnackBar سريع
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
              onPressed: _showAssignSheet,
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: Text(
                'إسناد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
      // تقييم الرضا (لو محلولة ومفيش تقييم)
      if (_complaint!.status == 4 && _complaint!.satisfactionLevel == null) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showRateSheet,
            icon: const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
            label: Text(
              'تقييم رضا العميل',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
      {'id': 3, 'name': 'انتظار العميل', 'color': Colors.amber},
      {'id': 4, 'name': 'محلولة', 'color': Colors.green},
      {'id': 5, 'name': 'مرفوضة', 'color': Colors.red},
      {'id': 6, 'name': 'مصعدة', 'color': Colors.purple},
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
                        final ok = await ComplaintsService.changeStatus(
                          complaintId: widget.complaintId,
                          newStatus: selectedStatus,
                          updatedBy: widget.username,
                        );

                        Navigator.pop(context);
                        _loadData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'تم تغيير الحالة بنجاح' : 'فشل تغيير الحالة',
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
void _showAssignSheet() {
  final isDark = ThemeService().isDarkMode;
  int? selectedEmpId;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'إسناد الشكوى لموظف',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _complaint!.assignedToName != null
                    ? 'المسند حالياً: ${_complaint!.assignedToName}'
                    : 'غير مسندة حالياً',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ComplaintsService.getActiveEmployees(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final emps = snapshot.data ?? [];
                  if (emps.isEmpty) {
                    return Text(
                      'لا يوجد موظفون نشطون',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
                    );
                  }
                  return SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: emps.length,
                      itemBuilder: (context, i) {
                        final emp = emps[i];
                        final id = (emp['EmployeeId'] ?? emp['EmployeeID'] ?? 0) as int;
                        final name = emp['FullName']?.toString() ?? 'موظف';
                        return ListTile(
                          onTap: () {
                            setSheetState(() => selectedEmpId = id);
                          },
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_rounded,
                                color: Colors.purple, size: 20),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.cairo(
                              color: AppColors.text(isDark),
                              fontWeight: selectedEmpId == id
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: selectedEmpId == id
                              ? const Icon(Icons.check_circle, color: Colors.purple)
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: selectedEmpId == null
                      ? null
                      : () async {
                          final ok = await ComplaintsService.assignComplaint(
                            complaintId: _complaint!.complaintId,
                            assignedTo: selectedEmpId,
                            updatedBy: widget.username,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'تم إسناد الشكوى بنجاح' : 'فشل الإسناد',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                          if (ok) _loadData();
                        },
                  icon: const Icon(Icons.check),
                  label: Text(
                    'تأكيد الإسناد',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
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
        ),
      ),
    ),
  );
}

void _showRateSheet() {
  final isDark = ThemeService().isDarkMode;
  int selected = 3;

  final levels = [
    {'id': 1, 'name': 'غير راضي', 'icon': Icons.sentiment_very_dissatisfied, 'color': Colors.red},
    {'id': 2, 'name': 'راضي جزئياً', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.orange},
    {'id': 3, 'name': 'متوسط', 'icon': Icons.sentiment_neutral, 'color': Colors.amber},
    {'id': 4, 'name': 'راضي', 'icon': Icons.sentiment_satisfied, 'color': Colors.lightGreen},
    {'id': 5, 'name': 'راضي جداً', 'icon': Icons.sentiment_very_satisfied, 'color': Colors.green},
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'تقييم رضا العميل',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(isDark),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: levels.map((level) {
                  final id = level['id'] as int;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selected = id),
                    child: Column(
                      children: [
                        Icon(
                          level['icon'] as IconData,
                          size: 36,
                          color: selected == id
                              ? level['color'] as Color
                              : AppColors.textHint(isDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          level['name'] as String,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: selected == id
                                ? level['color'] as Color
                                : AppColors.textSecondary(isDark),
                            fontWeight:
                                selected == id ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await ComplaintsService.rateComplaint(
                      complaintId: _complaint!.complaintId,
                      satisfactionLevel: selected,
                      updatedBy: widget.username,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'تم تسجيل التقييم بنجاح' : 'فشل تسجيل التقييم',
                          style: GoogleFonts.cairo(),
                        ),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                    if (ok) _loadData();
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: Text(
                    'تأكيد التقييم',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      // تغيير الحالة للمحلولة + الحل
                      final ok = await ComplaintsService.changeStatus(
                        complaintId: widget.complaintId,
                        newStatus: 4,
                        solution: solutionController.text.trim(),
                        updatedBy: widget.username,
                      );
                      // تسجيل التقييم لو مختلف عن الافتراضي
                      if (ok && selectedSatisfaction != 3) {
                        await ComplaintsService.rateComplaint(
                          complaintId: widget.complaintId,
                          satisfactionLevel: selectedSatisfaction,
                          updatedBy: widget.username,
                        );
                      }

                      Navigator.pop(context);
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'تم حل الشكوى بنجاح' : 'فشل في حفظ الحل',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: ok ? Colors.green : Colors.red,
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
// ===================================
// 🖼️ عارض الصورة بملء الشاشة
// ===================================
class _FullImageScreen extends StatelessWidget {
  final String url;
  final String title;

  const _FullImageScreen({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'فتح في المتصفح',
            onPressed: () async {
              try {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stack) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 64, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'تعذر تحميل الصورة',
                    style: GoogleFonts.cairo(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
