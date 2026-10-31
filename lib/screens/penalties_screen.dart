import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/penalty_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'add_penalty_screen.dart';

/// شاشة «الجزاءات» — قائمة بمرشحات حالة وبطاقات بهوية شاشات الموظفين
/// (مرساة كحلية + شارات حالة). إجراءات الاعتماد/الرفض/الإلغاء تظهر
/// بحسب الحالة والعلاقة بالصف، والخادم هو السلطة النهائية: رسالته
/// العربية عند 403 تظهر كما هي.
class PenaltiesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const PenaltiesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  final _service = PenaltyService();
  final _moneyFmt = intl.NumberFormat('#,##0.00');
  final _dateFmt = intl.DateFormat('yyyy/MM/dd');

  // مفتاح المرشح: all | pending | قيمة حالة الخادم كما هي
  String _filter = 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  int? _actingId;

  bool get _isDark => ThemeService().isDarkMode;
  bool get _canCreate => PermissionService().canCreatePenalties;

  static const List<(String, String)> _chips = [
    ('all', 'الكل'),
    ('pending', 'بانتظار الاعتماد'),
    ('Approved', 'معتمدة'),
    ('Rejected', 'مرفوضة'),
    ('Applied', 'مطبقة'),
    ('Cancelled', 'ملغية'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> rows;
      if (_filter == 'pending') {
        // رقاقة الانتظار = قائمة الاعتماد القابلة للتنفيذ من الخادم
        rows = await _service.pending();
      } else if (_filter == 'all') {
        rows = await _service.list();
      } else {
        rows = await _service.list(status: _filter);
      }
      if (!mounted) return;
      setState(() {
        // ترشيح إضافي بالحالة عند اختيار رقاقة حالة محددة (حماية إن
        // تجاهل الخادم معامل الحالة)
        _rows = _filter == 'all' || _filter == 'pending'
            ? rows
            : rows.where((r) => r['status']?.toString() == _filter).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل الجزاءات';
        _loading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  Future<void> _runAction(
    Map<String, dynamic> row,
    String verb,
    Future<Map<String, dynamic>> Function(int id) action,
    String successMessage,
  ) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(_isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$verb جزاء',
          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                color: AppColors.text(_isDark),
                fontWeight: FontWeight.bold,
              ),
        ),
        content: Text(
          'هل تريد $verb جزاء «${row['employeeName'] ?? ''}» (${penaltyTypeLine(row)}) لشهر ${row['targetMonth'] ?? ''}؟',
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(_isDark),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'تراجع',
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              verb,
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: _isDark ? AppColors.gold : AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || id <= 0) return;
    setState(() => _actingId = id);
    try {
      await action(id);
      if (!mounted) return;
      _showSuccess(successMessage);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('فشل تنفيذ الإجراء');
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPenaltyScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text(
          'الجزاءات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildAnchorHeader(),
          ),
          const SizedBox(height: 12),
          _buildChips(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// بطاقة المرساة الكحلية: أيقونة الجزاءات وعنوانها وعدّادات سريعة،
  /// وحبة «جزاء جديد» الذهبية عند توفر صلاحية الإنشاء
  Widget _buildAnchorHeader() {
    final textTheme = Theme.of(context).textTheme;
    final pendingCount =
        _rows.where((r) => r['status']?.toString() == 'Pending').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جزاءات الموظفين',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المعروض: ${_rows.length} جزاء • بانتظار الاعتماد: $pendingCount',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_canCreate) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _openCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(
                  'جزاء جديد',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (key, label) = _chips[i];
          final selected = _filter == key;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) {
              if (_filter == key) return;
              setState(() => _filter = key);
              _load();
            },
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? (_isDark ? AppColors.navy : Colors.white)
                      : AppColors.textSecondary(_isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
            selectedColor: _isDark ? AppColors.gold : AppColors.navy,
            backgroundColor: AppColors.surface(_isDark),
            side: BorderSide(
              color: selected
                  ? Colors.transparent
                  : AppColors.divider(_isDark),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppError(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const AppEmpty(
        icon: Icons.gavel_rounded,
        message: 'لا توجد جزاءات مطابقة لهذا المرشح.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _rows.length,
        itemBuilder: (context, i) => _buildCard(_rows[i]),
      ),
    );
  }

  /// بطاقة جزاء: الاسم والمسمى وشارة الحالة، سطر النوع، المبلغ
  /// المحسوب كبيرًا عند الاعتماد/التطبيق (وإلا القيمة الخام)، الشهر
  /// المستهدف والسبب، ثم المنشئ والتاريخ وإجراءات الحالة
  Widget _buildCard(Map<String, dynamic> row) {
    final textTheme = Theme.of(context).textTheme;
    final status = row['status']?.toString();
    final isDays = row['penaltyType']?.toString() != 'Amount';
    final computed = (row['computedAmount'] as num?)?.toDouble() ??
        double.tryParse('${row['computedAmount'] ?? ''}');
    final showComputed =
        computed != null && (status == 'Approved' || status == 'Applied');
    final fixed = (row['fixedAmount'] as num?)?.toDouble() ??
        double.tryParse('${row['fixedAmount'] ?? ''}');
    final job = row['employeeJobTitle']?.toString() ??
        row['jobTitle']?.toString() ??
        '';
    final createdAt = DateTime.tryParse(row['createdAt']?.toString() ?? '');
    final mine = penaltyCreatedByMe(row);
    final acting = _actingId == (row['id'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: AppColors.surface(_isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['employeeName']?.toString() ?? '—',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (job.isNotEmpty)
                        Text(
                          job,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: penaltyStatusLabel(status),
                  color: penaltyStatusColor(status, _isDark),
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        penaltyTypeLine(row),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'شهر الخصم: ${row['targetMonth'] ?? '—'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 12,
                        ),
                      ),
                      if (row['rolledFrom'] != null)
                        Text(
                          'نُقل من شهر ${row['rolledFrom']}',
                          style: textTheme.bodySmall?.copyWith(
                            color: _isDark
                                ? AppColors.warningLight
                                : AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showComputed)
                  Text(
                    '${_moneyFmt.format(computed)} جـ',
                    style: textTheme.titleLarge?.copyWith(
                      color: _isDark ? AppColors.gold : AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else if (!isDays && fixed != null)
                  Text(
                    '${_moneyFmt.format(fixed)} جـ',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.text(_isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else if (isDays)
                  Text(
                    '${formatPenaltyDays(row['daysCount'])} يوم',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.text(_isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            if (row['reason'] != null &&
                row['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'السبب: ${row['reason']}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary(_isDark),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'بواسطة ${row['createdByName'] ?? '—'}'
                    '${createdAt != null ? ' • ${_dateFmt.format(createdAt)}' : ''}'
                    '${row['approvedByName'] != null ? ' • اعتمدها ${row['approvedByName']}' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            ..._buildActions(row, status, mine, acting),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    Map<String, dynamic> row,
    String? status,
    bool mine,
    bool acting,
  ) {
    final canAct = status == 'Pending' && !mine;
    final canCancel =
        status == 'Pending' || (status == 'Approved' && mine);
    if (!canAct && !canCancel && !(status == 'Pending' && mine)) {
      return const [];
    }
    final textTheme = Theme.of(context).textTheme;
    return [
      const SizedBox(height: 12),
      if (status == 'Pending' && mine)
        Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 15,
              color: _isDark ? AppColors.warningLight : AppColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              'بانتظار الاعتماد',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      if (canAct || canCancel)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              if (canAct) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: acting
                        ? null
                        : () => _runAction(
                              row,
                              'اعتماد',
                              _service.approve,
                              'تم اعتماد الجزاء',
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _isDark ? AppColors.gold : AppColors.navy,
                      foregroundColor:
                          _isDark ? AppColors.navy : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 17),
                    label: const Text('اعتماد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: acting
                        ? null
                        : () => _runAction(
                              row,
                              'رفض',
                              _service.reject,
                              'تم رفض الجزاء',
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _isDark ? AppColors.errorLight : AppColors.error,
                      side: BorderSide(
                        color:
                            _isDark ? AppColors.errorLight : AppColors.error,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('رفض'),
                  ),
                ),
              ],
              if (canCancel) ...[
                if (canAct) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: acting
                        ? null
                        : () => _runAction(
                              row,
                              'إلغاء',
                              _service.cancel,
                              'تم إلغاء الجزاء',
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(_isDark),
                      side: BorderSide(color: AppColors.divider(_isDark)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    icon: const Icon(Icons.block_rounded, size: 17),
                    label: const Text('إلغاء'),
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}
