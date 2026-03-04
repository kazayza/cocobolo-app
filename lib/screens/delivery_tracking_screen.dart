import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/theme_service.dart';
import '../services/app_colors.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final int userId;
  final String username;

  const DeliveryTrackingScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveries = [];
  Map<String, dynamic> _stats = {};
  String _selectedFilter = 'all';
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
      // جلب الإحصائيات
      final statsRes = await http.get(
        Uri.parse('$baseUrl/api/delivery/stats'),
      );

      // جلب الفواتير
      String url = '$baseUrl/api/delivery/pending';
      if (_selectedFilter != 'all') {
        url += '?status=$_selectedFilter';
      }
      final deliveriesRes = await http.get(Uri.parse(url));

      if (statsRes.statusCode == 200 && deliveriesRes.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(statsRes.body);
          _deliveries = List<Map<String, dynamic>>.from(jsonDecode(deliveriesRes.body));
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'فشل في تحميل البيانات';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل في الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  // ===================================
  // تحديث حالة التسليم
  // ===================================
  Future<void> _markAsDelivered(int transactionId) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/delivery/$transactionId/deliver'),
        headers: {'Content-Type': 'application/json'},
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSnackBar('تم تأكيد التسليم بنجاح ✅', Colors.green);
        _loadData();
      } else {
        _showSnackBar('فشل في تحديث الحالة', Colors.red);
      }
    } catch (e) {
      _showSnackBar('حدث خطأ في الاتصال', Colors.red);
    }
  }

  // ===================================
  // الاتصال بالعميل
  // ===================================
  Future<void> _callClient(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('رقم الهاتف غير متوفر', Colors.orange);
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('لا يمكن إجراء المكالمة', Colors.red);
    }
  }

  // ===================================
  // واتساب
  // ===================================
  Future<void> _whatsappClient(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('رقم الهاتف غير متوفر', Colors.orange);
      return;
    }

    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '2$formattedPhone';
    }

    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('لا يمكن فتح واتساب', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_shipping, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'متابعة التسليمات',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.navy,
              fontSize: 18,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : AppColors.navy,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.gold),
          onPressed: _loadData,
        ),
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
            'جاري تحميل التسليمات...',
            style: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
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
    return Column(
      children: [
        // الإحصائيات
        _buildStatsCards(isDark),

        // الفلاتر
        _buildFilters(isDark),

        // القائمة
        Expanded(
          child: _deliveries.isEmpty
              ? _buildEmptyState(isDark)
              : _buildDeliveriesList(isDark),
        ),
      ],
    );
  }

  // ===================================
  // كروت الإحصائيات
  // ===================================
  Widget _buildStatsCards(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              title: 'متأخر',
              count: _stats['Overdue'] ?? 0,
              color: Colors.red,
              icon: Icons.warning_amber,
              onTap: () => _setFilter('overdue'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              title: 'اليوم',
              count: _stats['Today'] ?? 0,
              color: Colors.orange,
              icon: Icons.today,
              onTap: () => _setFilter('today'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              title: 'هذا الاسبوع',
              count: _stats['Soon'] ?? 0,
              color: Colors.amber,
              icon: Icons.schedule,
              onTap: () => _setFilter('soon'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              title: 'قادم',
              count: _stats['Upcoming'] ?? 0,
              color: Colors.green,
              icon: Icons.event,
              onTap: () => _setFilter('upcoming'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedFilter == title.toLowerCase() ||
        (_selectedFilter == 'soon' && title == 'قريب') ||
        (_selectedFilter == 'upcoming' && title == 'قادم') ||
        (_selectedFilter == 'overdue' && title == 'متأخر') ||
        (_selectedFilter == 'today' && title == 'اليوم');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary(isDark),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = _selectedFilter == filter ? 'all' : filter;
    });
    _loadData();
  }

  // ===================================
  // الفلاتر
  // ===================================
  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'إجمالي: ${_stats['TotalPending'] ?? 0} فاتورة',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (_selectedFilter != 'all')
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedFilter = 'all');
                _loadData();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text('إلغاء الفلتر', style: GoogleFonts.cairo(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
              ),
            ),
        ],
      ),
    );
  }

  // ===================================
  // قائمة الفواتير
  // ===================================
  Widget _buildDeliveriesList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) {
          return _buildDeliveryCard(_deliveries[index], isDark);
        },
      ),
    );
  }

  // ===================================
  // كارت الفاتورة
  // ===================================
  Widget _buildDeliveryCard(Map<String, dynamic> delivery, bool isDark) {
    final daysRemaining = delivery['DaysRemaining'] ?? 0;
    final status = delivery['DeliveryStatus'] ?? 'upcoming';
    final dueDate = delivery['DueDate'] != null
        ? DateTime.tryParse(delivery['DueDate'].toString())
        : null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'overdue':
        statusColor = Colors.red;
        statusText = 'متأخر ${daysRemaining.abs()} يوم';
        statusIcon = Icons.warning_amber;
        break;
      case 'today':
        statusColor = Colors.orange;
        statusText = 'اليوم';
        statusIcon = Icons.today;
        break;
      case 'soon':
        statusColor = Colors.amber;
        statusText = 'بعد $daysRemaining يوم';
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.green;
        statusText = 'بعد $daysRemaining يوم';
        statusIcon = Icons.event;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // الهيدر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '#${delivery['TransactionID']}',
                  style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم العميل
                Row(
                  children: [
                    Icon(Icons.person, color: AppColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        delivery['ClientName'] ?? 'غير محدد',
                        style: GoogleFonts.cairo(
                          color: AppColors.text(isDark),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // العنوان
                if (delivery['Address'] != null && delivery['Address'].toString().isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          delivery['Address'],
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // التواريخ
                Row(
                  children: [
                    // تاريخ الفاتورة
                    Expanded(
                      child: _buildDateInfo(
                        'تاريخ الفاتورة',
                        delivery['TransactionDate'],
                        Icons.receipt,
                        Colors.blue,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ميعاد التسليم
                    Expanded(
                      child: _buildDateInfo(
                        'ميعاد التسليم',
                        delivery['DueDate'],
                        Icons.event,
                        statusColor,
                        isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // الأزرار
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // اتصال
                _buildActionButton(
                  icon: Icons.phone,
                  color: Colors.green,
                  onTap: () => _callClient(delivery['Phone']),
                ),
                const SizedBox(width: 8),

                // واتساب
                _buildActionButton(
                  icon: Icons.chat,
                  color: Colors.teal,
                  onTap: () => _whatsappClient(delivery['Phone']),
                ),
                const SizedBox(width: 8),

                // تأكيد التسليم
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmDeliveryDialog(delivery, isDark),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      'تأكيد التسليم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, dynamic date, IconData icon, Color color, bool isDark) {
    String formattedDate = '--/--/----';
    if (date != null) {
      final parsedDate = DateTime.tryParse(date.toString());
      if (parsedDate != null) {
        formattedDate = DateFormat('yyyy/MM/dd').format(parsedDate);
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: GoogleFonts.cairo(
              color: AppColors.text(isDark),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ===================================
  // تأكيد التسليم Dialog
  // ===================================
  void _showConfirmDeliveryDialog(Map<String, dynamic> delivery, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(
              'تأكيد التسليم',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.text(isDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تم تسليم الفاتورة للعميل؟',
              style: GoogleFonts.cairo(color: AppColors.text(isDark)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'العميل: ${delivery['ClientName'] ?? 'غير محدد'}',
                    style: GoogleFonts.cairo(
                      color: AppColors.text(isDark),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'رقم الفاتورة: #${delivery['TransactionID']}',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            onPressed: () {
              Navigator.pop(context);
              _markAsDelivered(delivery['TransactionID']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('تأكيد التسليم', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  // ===================================
  // حالة فارغة
  // ===================================
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تسليمات معلقة 🎉',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تم تسليم جميع الفواتير',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}