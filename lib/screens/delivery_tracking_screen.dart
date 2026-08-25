import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../features/home/widgets/home_accent.dart';
import '../services/permission_service.dart';
import 'delivery_details_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  متابعة التسليمات — نسخة 2026
///  - 5 كروت إحصائيات (الكل/متأخر/اليوم/قريب/مسلم)
///  - بحث بالعميل + فلترة تاريخ (من/إلى + نوع)
///  - المبالغ حسب الصلاحية
///  - تفاصيل كاملة لكل فاتورة
/// ─────────────────────────────────────────────────────────────
class DeliveryTrackingScreen extends StatefulWidget {
  final int userId;
  final String username;

  const DeliveryTrackingScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveries = [];
  Map<String, dynamic> _stats = {};
  String _selectedFilter = 'overdue'; // يفتح على المتأخر أولاً
  String _searchText = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _dateFilterType = 'due'; // due | invoice | delivered
  String? _error;

  final PermissionService _perms = PermissionService();

  // ── الصلاحيات (زي DeliveryPermissions في بلازور) ──────────
  bool get _canSeeAmounts =>
      _perms.isAdmin || _perms.isAccountManager || _perms.isAccount;
  bool get _canConfirmDelivery =>
      _perms.isAdmin || _perms.isSales || _perms.role?.toLowerCase() == 'user';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // تحميل البيانات
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // بناء الـ query params
      final params = <String, String>{};
      if (_selectedFilter != 'all') params['status'] = _selectedFilter;
      if (_searchText.trim().isNotEmpty) {
        params['search'] = _searchText.trim();
      }
      if (_fromDate != null) {
        params['dateFrom'] = DateFormat('yyyy-MM-dd').format(_fromDate!);
      }
      if (_toDate != null) {
        params['dateTo'] = DateFormat('yyyy-MM-dd').format(_toDate!);
      }
      if (_dateFilterType != 'due') {
        params['dateFilterType'] = _dateFilterType;
      }

      final qs = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

      final statsRes = await http.get(
        Uri.parse('$baseUrl/api/delivery/stats$qs'),
      );
      final deliveriesRes = await http.get(
        Uri.parse('$baseUrl/api/delivery/list$qs'),
      );

      if (statsRes.statusCode == 200 && deliveriesRes.statusCode == 200) {
        final statsJson = jsonDecode(statsRes.body);
        final listJson = jsonDecode(deliveriesRes.body);

        setState(() {
          _stats = statsJson is Map ? Map<String, dynamic>.from(statsJson) : {};
          _deliveries = listJson is Map && listJson['data'] is List
              ? List<Map<String, dynamic>>.from(
                  (listJson['data'] as List).map(
                    (e) => Map<String, dynamic>.from(e as Map),
                  ),
                )
              : [];
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

  // ═══════════════════════════════════════════════════════════
  // تأكيد التسليم
  // ═══════════════════════════════════════════════════════════
  Future<void> _confirmDelivery(Map<String, dynamic> delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: Text(
          'هل تريد تأكيد تسليم الفاتورة #${delivery['TransactionID']} '
          'للعميل ${delivery['ClientName'] ?? ''}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('نعم، تم التسليم'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/delivery/${delivery['TransactionID']}/deliver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deliveryEmployeeName': widget.username}),
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSnackBar('✅ تم تأكيد التسليم بنجاح', Colors.green);
        _loadData();
      } else {
        _showSnackBar('فشل في تحديث الحالة', Colors.red);
      }
    } catch (e) {
      _showSnackBar('حدث خطأ في الاتصال', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // تواصل
  // ═══════════════════════════════════════════════════════════
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

  Future<void> _whatsappClient(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('رقم الهاتف غير متوفر', Colors.orange);
      return;
    }
    String formatted = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formatted.startsWith('0')) formatted = '2$formatted';
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('لا يمكن فتح واتساب', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة التسليمات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
          ? _buildError(theme)
          : _buildBody(theme, isDark),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // الإحصائيات
        _buildStatsCards(theme),

        // البحث
        _buildSearch(theme),

        // فلتر التاريخ
        _buildDateFilter(theme),

        // العنوان
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_deliveries.length} فاتورة',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              if (_selectedFilter != 'all' ||
                  _searchText.isNotEmpty ||
                  _fromDate != null ||
                  _toDate != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'all';
                      _searchText = '';
                      _fromDate = null;
                      _toDate = null;
                      _dateFilterType = 'due';
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.clear_rounded, size: 15),
                  label: const Text(
                    'مسح الفلاتر',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: _deliveries.isEmpty
              ? _buildEmptyState(theme)
              : _buildDeliveriesList(theme, isDark),
        ),
      ],
    );
  }

  // ── كروت الإحصائيات ───────────────────────────────────────
  Widget _buildStatsCards(ThemeData theme) {
    final cards = [
      _StatCardData(
        label: 'الكل',
        count: _stats['TotalCount'] ?? 0,
        color: HomeAccent.indigo,
        icon: Icons.list_alt_rounded,
        status: 'all',
      ),
      _StatCardData(
        label: 'متأخر',
        count: _stats['Overdue'] ?? 0,
        color: const Color(0xFFE53935),
        icon: Icons.warning_amber_rounded,
        status: 'overdue',
      ),
      _StatCardData(
        label: 'اليوم',
        count: _stats['Today'] ?? 0,
        color: const Color(0xFFFFA000),
        icon: Icons.today_rounded,
        status: 'today',
      ),
      _StatCardData(
        label: 'قريب',
        count: _stats['Soon'] ?? 0,
        color: const Color(0xFFFFB300),
        icon: Icons.schedule_rounded,
        status: 'soon',
      ),
      _StatCardData(
        label: 'مسلم',
        count: _stats['Delivered'] ?? 0,
        color: const Color(0xFF43A047),
        icon: Icons.check_circle_rounded,
        status: 'delivered',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // كروت الحالات — شبكة مدمجة (3 × 2) بدل شريط أفقي
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 3;
              return Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final card in cards)
                    _CompactStatCard(
                      card: card,
                      width: itemWidth,
                      selected: _selectedFilter == card.status,
                      onTap: () {
                        setState(() {
                          _selectedFilter = _selectedFilter == card.status
                              ? 'all'
                              : card.status;
                        });
                        _loadData();
                      },
                    ),
                ],
              );
            },
          ),
          // المبالغ (للأدمن ومدير الحسابات والمحاسب فقط)
          if (_canSeeAmounts) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: theme.brightness == Brightness.dark
                      ? [HomeAccent.navyDark, HomeAccent.navyLight]
                      : [HomeAccent.navy, const Color(0xFF2C4E77)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _AmountChip(
                    label: 'الإجمالي',
                    value: _fmt(_stats['TotalGrandTotal']),
                    color: Colors.white,
                  ),
                  _AmountChip(
                    label: 'المدفوع',
                    value: _fmt(_stats['TotalPaidAmount']),
                    color: const Color(0xFF66BB6A),
                  ),
                  _AmountChip(
                    label: 'المتبقي',
                    value: _fmt(_stats['TotalRemaining']),
                    color: const Color(0xFFFF8A65),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── البحث ─────────────────────────────────────────────────
  Widget _buildSearch(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        onChanged: (v) {
          setState(() => _searchText = v);
          // Debounce بسيط
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && v == _searchText) _loadData();
          });
        },
        decoration: InputDecoration(
          hintText: 'ابحث بالعميل أو الهاتف...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    setState(() => _searchText = '');
                    _loadData();
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  // ── فلتر التاريخ ──────────────────────────────────────────
  Widget _buildDateFilter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // من
          Expanded(
            child: _DateField(
              label: _fromDate == null
                  ? 'من'
                  : DateFormat('yyyy/MM/dd').format(_fromDate!),
              icon: Icons.calendar_today_rounded,
              onTap: () => _pickDate(from: true),
              onClear: _fromDate == null
                  ? null
                  : () {
                      setState(() => _fromDate = null);
                      _loadData();
                    },
            ),
          ),
          const SizedBox(width: 8),
          // إلى
          Expanded(
            child: _DateField(
              label: _toDate == null
                  ? 'إلى'
                  : DateFormat('yyyy/MM/dd').format(_toDate!),
              icon: Icons.event_rounded,
              onTap: () => _pickDate(from: false),
              onClear: _toDate == null
                  ? null
                  : () {
                      setState(() => _toDate = null);
                      _loadData();
                    },
            ),
          ),
          const SizedBox(width: 8),
          // نوع التاريخ
          PopupMenuButton<String>(
            initialValue: _dateFilterType,
            tooltip: 'نوع التاريخ',
            onSelected: (v) {
              setState(() => _dateFilterType = v);
              _loadData();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'due', child: Text('تاريخ الاستحقاق')),
              PopupMenuItem(value: 'invoice', child: Text('تاريخ الفاتورة')),
              PopupMenuItem(value: 'delivered', child: Text('تاريخ التسليم')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    _loadData();
  }

  // ── قائمة الفواتير ────────────────────────────────────────
  Widget _buildDeliveriesList(ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: HomeAccent.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) =>
            _buildDeliveryCard(_deliveries[index], theme, isDark),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد فواتير مطابقة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرّب تغيير الفلاتر أو الفترة الزمنية',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── كارت الفاتورة ─────────────────────────────────────────
  Widget _buildDeliveryCard(
    Map<String, dynamic> delivery,
    ThemeData theme,
    bool isDark,
  ) {
    final daysRemaining = delivery['DaysRemaining'] ?? 0;
    final status = delivery['DeliveryStatus'] ?? 'upcoming';
    final isDelivered = status == 'delivered';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'overdue':
        statusColor = const Color(0xFFE53935);
        statusText = 'متأخر ${daysRemaining.abs()} يوم';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'today':
        statusColor = const Color(0xFFFFA000);
        statusText = 'اليوم';
        statusIcon = Icons.today_rounded;
        break;
      case 'soon':
        statusColor = const Color(0xFFFFB300);
        statusText = 'بعد $daysRemaining يوم';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'delivered':
        statusColor = const Color(0xFF43A047);
        statusText = 'تم التسليم';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = HomeAccent.accent;
        statusText = 'بعد $daysRemaining يوم';
        statusIcon = Icons.event_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: isDelivered ? 0.2 : 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // الهيدر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '#${delivery['TransactionID']}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم العميل
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        delivery['ClientName'] ?? '—',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_canSeeAmounts)
                      Text(
                        _fmt(delivery['GrandTotal']),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // المعلومات
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.event_rounded,
                      text: _date(delivery['DueDate']),
                      theme: theme,
                    ),
                    if (delivery['DeliveryEmployeeName'] != null)
                      _InfoChip(
                        icon: Icons.person_outline_rounded,
                        text: delivery['DeliveryEmployeeName'].toString(),
                        theme: theme,
                      ),
                    if (_canSeeAmounts &&
                        (delivery['RemainingAmount'] ?? 0) > 0)
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        text: 'متبقي ${_fmt(delivery['RemainingAmount'])}',
                        theme: theme,
                        color: const Color(0xFFE53935),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // الأزرار
          Container(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                // التفاصيل
                _ActionBtn(
                  icon: Icons.open_in_full_rounded,
                  color: theme.colorScheme.primary,
                  tooltip: 'التفاصيل',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeliveryDetailsScreen(
                          transactionId:
                              (delivery['TransactionID'] ?? 0) as int,
                          username: widget.username,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                // اتصال
                if ((delivery['Phone'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.call_rounded,
                    color: Colors.green,
                    tooltip: 'اتصال',
                    onTap: () => _callClient(delivery['Phone']?.toString()),
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.chat_rounded,
                    color: const Color(0xFF25D366),
                    tooltip: 'واتساب',
                    onTap: () => _whatsappClient(delivery['Phone']?.toString()),
                  ),
                ],
                const Spacer(),
                // تأكيد التسليم
                if (_canConfirmDelivery && !isDelivered)
                  _ActionBtn(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF43A047),
                    tooltip: 'تأكيد التسليم',
                    onTap: () => _confirmDelivery(delivery),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets مساعدة
// ═══════════════════════════════════════════════════════════

/// كارت إحصائية مدمج (شبكة)
class _CompactStatCard extends StatelessWidget {
  final _StatCardData card;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _CompactStatCard({
    required this.card,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? card.color.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? card.color
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(card.icon, color: card.color, size: 17),
            const SizedBox(height: 3),
            Text(
              '${card.count}',
              style: TextStyle(
                color: card.color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              card.label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCardData {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String status;

  const _StatCardData({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.status,
  });
}

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.clear_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.theme,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: c,
            fontWeight: color != null ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
