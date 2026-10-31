import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/exemption_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';
import '../widgets/identity_dialog.dart';
import 'add_exemption_screen.dart';
import 'hr/exemption_status.dart';

/// استثناءات الموظفين اليومية — مرآة صفحتي بلازور ExemptionsPage
/// (إدارة) وMyExemptionsPage (طلباتي): الخادم يقيّد غير المديرين
/// بسجلاتهم، والأدوار والمطالبات تفتح البوابات كما في بلازور حرفيًا.
/// الهوية: مرساة كحلية + شارات حالة من التعريف الواحد في
/// exemption_status.dart، وكل فشل ظاهر مع إعادة محاولة.
class ExemptionsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExemptionsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ExemptionsScreen> createState() => _ExemptionsScreenState();
}

class _ExemptionsScreenState extends State<ExemptionsScreen> {
  final ExemptionService _service = ExemptionService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _rows = [];
  Map<String, int> _counts = {'all': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
  bool _loading = true;
  String? _error;
  String? _statusFilter; // null = الكل
  DateTime? _dateFilter;
  bool _acting = false;

  PermissionService get _perms => PermissionService();
  bool get _isDark => ThemeService().isDarkMode;
  bool get _canView => _perms.canViewExemptions;
  bool get _isManagerScope => _perms.isExemptionManagerRole || _perms.canView(FormNames.dailyExemptions);
  bool get _canAdd => _perms.canAddExemptions || _perms.employeeId != null;
  bool get _canApprove => _perms.canApproveExemptions;
  bool get _canDelete => _perms.canDeleteExemptions;

  @override
  void initState() {
    super.initState();
    if (_canView) _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getList(
          status: _statusFilter,
          employeeName: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          date: _dateFilter == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_dateFilter!),
        ),
        _service.getList(),
      ]);
      if (!mounted) return;
      final all = results[1];
      setState(() {
        _rows = results[0];
        _counts = {
          'all': all.length,
          'pending': all.where((r) => exemptionStatusKey(r as Map) == 'pending').length,
          'approved': all.where((r) => exemptionStatusKey(r as Map) == 'approved').length,
          'rejected': all.where((r) => exemptionStatusKey(r as Map) == 'rejected').length,
        };
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
        _error = 'فشل الاتصال بالخادم';
        _loading = false;
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? (mounted ? (_isDark ? AppColors.errorLight : AppColors.error) : null)
            : null,
      ),
    );
  }

  Future<void> _approve(Map row) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _service.approve((row['ExemptionID'] as num).toInt());
      _snack('تم اعتماد الاستثناء');
      await _loadAll();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject(Map row) async {
    final outcome = await showDialog<_RejectOutcome>(
      context: context,
      builder: (_) => _RejectExemptionDialog(row: row),
    );
    if (outcome == null || _acting) return;
    setState(() => _acting = true);
    try {
      await _service.reject(
        (row['ExemptionID'] as num).toInt(),
        reason: outcome.reason,
      );
      _snack('تم رفض الاستثناء');
      await _loadAll();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _delete(Map row) async {
    final confirmed = await showIdentityConfirmDialog(
      context: context,
      icon: Icons.delete_rounded,
      title: 'حذف الاستثناء',
      message:
          'سيُحذف استثناء ${row['EmployeeName'] ?? ''} بتاريخ ${_dateLabel(row)} نهائيًا، ومعه سجل الحضور المرتبط إن كان معتمدًا.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!confirmed || _acting) return;
    setState(() => _acting = true);
    try {
      await _service.delete((row['ExemptionID'] as num).toInt());
      _snack('تم حذف الاستثناء');
      await _loadAll();
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExemptionScreen(username: widget.username),
      ),
    );
    if (result == true) _loadAll();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
      _loadAll();
    }
  }

  String _dateLabel(Map row) {
    final raw = row['ExemptionDate']?.toString() ?? '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return DateFormat('yyyy/MM/dd').format(d);
  }

  String _dayName(Map row) {
    final d = DateTime.tryParse(row['ExemptionDate']?.toString() ?? '');
    if (d == null) return '';
    return DateFormat('EEEE', 'ar').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frmDailyExemptions'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: const Text('استثناءات الموظفين'),
      ),
      body: !_canView
          ? const AppEmpty(
              message: 'لا توجد صلاحية لعرض الاستثناءات',
              icon: Icons.lock_rounded,
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildAnchor(),
                  ),
                  const SizedBox(height: 12),
                  _buildChips(),
                  _buildSearchRow(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
    );
  }

  Widget _buildAnchor() {
    final textTheme = Theme.of(context).textTheme;
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
                  Icons.event_busy_rounded,
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
                      _isManagerScope ? 'استثناءات الموظفين' : 'استثناءاتي',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'الكل: ${_counts['all']} • بانتظار الاعتماد: ${_counts['pending']}',
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
          if (_canAdd) ...[
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
                  _perms.canAddExemptions ? 'استثناء جديد' : 'طلب جديد',
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
    final chips = <(String?, String, String)>[
      (null, 'الكل', 'all'),
      ('Pending', 'قيد الاعتماد', 'pending'),
      ('Approved', 'معتمد', 'approved'),
      ('Rejected', 'مرفوض', 'rejected'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label, countKey) = chips[i];
          final selected = _statusFilter == value;
          return ChoiceChip(
            label: Text('$label (${_counts[countKey]})'),
            selected: selected,
            onSelected: (_) {
              setState(() => _statusFilter = value);
              _loadAll();
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث باسم الموظف...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _loadAll(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _pickDate,
            icon: Icon(
              _dateFilter == null
                  ? Icons.calendar_month_rounded
                  : Icons.event_available_rounded,
              size: 20,
            ),
            tooltip: 'تصفية بتاريخ',
          ),
          if (_dateFilter != null)
            IconButton(
              onPressed: () {
                setState(() => _dateFilter = null);
                _loadAll();
              },
              icon: const Icon(Icons.clear_rounded, size: 20),
              tooltip: 'إلغاء التاريخ',
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppError(message: _error!, onRetry: _loadAll);
    }
    if (_rows.isEmpty) {
      return const AppEmpty(message: 'لا توجد استثناءات مطابقة');
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildCard(_rows[i] as Map),
      ),
    );
  }

  Widget _buildCard(Map row) {
    final textTheme = Theme.of(context).textTheme;
    final statusKey = exemptionStatusKey(row);
    final reason = row['ReasonCode']?.toString() ?? '';
    final isFullDay = row['IsFullDay'] != false && row['IsFullDay'] != 0;
    final hours = row['Hours'];
    final isDeducted = row['IsDeducted'] != false && row['IsDeducted'] != 0;
    final canDecide = statusKey == 'pending' && _canApprove;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(row),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['EmployeeName']?.toString() ?? '—',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(_isDark),
                      ),
                    ),
                    if ((row['Department']?.toString() ?? '').isNotEmpty)
                      Text(
                        row['Department'].toString(),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                  ],
                ),
              ),
              StatusBadge(
                label: exemptionStatusLabel(statusKey),
                color: exemptionStatusColor(statusKey, _isDark),
                icon: exemptionStatusIcon(statusKey),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: reason.isEmpty ? '—' : reason,
                color: exemptionReasonColor(reason, _isDark),
                icon: exemptionReasonIcon(reason),
                small: true,
              ),
              StatusBadge(
                label: '${_dateLabel(row)} • ${_dayName(row)}',
                color: AppColors.neutral,
                icon: Icons.calendar_today_rounded,
                small: true,
              ),
              StatusBadge(
                label: isFullDay
                    ? 'يوم كامل'
                    : 'جزئي • ${hours ?? '—'} ساعة',
                color: AppColors.neutral,
                icon: Icons.schedule_rounded,
                small: true,
              ),
              StatusBadge(
                label: isDeducted ? 'يُخصم من الراتب' : 'لا يُخصم',
                color: isDeducted
                    ? (_isDark ? AppColors.errorLight : AppColors.error)
                    : (_isDark ? AppColors.successLight : AppColors.success),
                icon: isDeducted
                    ? Icons.money_off_rounded
                    : Icons.verified_rounded,
                small: true,
              ),
            ],
          ),
          if ((row['Description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row['Description'].toString(),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.text(_isDark),
              ),
            ),
          ],
          if ((row['Notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row['Notes'].toString(),
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if ((row['CreatedBy']?.toString() ?? '').isNotEmpty)
                'أُنشئ بواسطة ${row['CreatedBy']}',
              if ((row['ApprovedBy']?.toString() ?? '').isNotEmpty)
                'القرار: ${row['ApprovedBy']}',
            ].join(' • '),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textHint(_isDark),
              fontSize: 11,
            ),
          ),
          if (canDecide || _canDelete) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (canDecide) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _acting ? null : () => _approve(row),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('اعتماد'),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _acting ? null : () => _reject(row),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _isDark ? AppColors.errorLight : AppColors.error,
                        side: BorderSide(
                          color: _isDark
                              ? AppColors.errorLight
                              : AppColors.error,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_canDelete) ...[
                  if (canDecide) const SizedBox(width: 4),
                  IconButton(
                    onPressed: _acting ? null : () => _delete(row),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: _isDark ? AppColors.errorLight : AppColors.error,
                    ),
                    tooltip: 'حذف الاستثناء',
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(Map row) {
    final gender = row['Gender']?.toString();
    if (gender != null && gender.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          gender == 'أنثى'
              ? 'assets/images/default_avatar_female.png'
              : 'assets/images/default_avatar_male.png',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      );
    }
    final name = row['EmployeeName']?.toString() ?? '';
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.navy.withValues(alpha: _isDark ? 0.5 : 0.1),
      child: Text(
        name.isNotEmpty ? name.characters.first : '؟',
        style: TextStyle(
          color: _isDark ? AppColors.goldLight : AppColors.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// نتيجة حوار الرفض: تأكيد مع سبب اختياري.
class _RejectOutcome {
  final String? reason;
  const _RejectOutcome(this.reason);
}

/// حوار رفض يملك وحدة تحكّمه داخل حالته — تُحرَّر في dispose الخاصة
/// بالحوار بعد زوال مساره تمامًا (نفس درس حوارات السلف: تحرير وحدة
/// تحكّم من حالة الشاشة لحظة بدء إغلاق الحوار كان يُسقط التطبيق).
class _RejectExemptionDialog extends StatefulWidget {
  final Map row;
  const _RejectExemptionDialog({required this.row});

  @override
  State<_RejectExemptionDialog> createState() =>
      _RejectExemptionDialogState();
}

class _RejectExemptionDialogState extends State<_RejectExemptionDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final name = widget.row['EmployeeName']?.toString() ?? '';
    return IdentityDialog(
      icon: Icons.cancel_rounded,
      title: 'رفض الاستثناء',
      subtitle: name,
      actions: [
        IdentityDialogAction(
          label: 'إلغاء',
          onPressed: () => Navigator.pop(context),
        ),
        IdentityDialogAction(
          label: 'رفض',
          icon: Icons.close_rounded,
          danger: true,
          filled: true,
          onPressed: () => Navigator.pop(
            context,
            _RejectOutcome(_reasonController.text.trim()),
          ),
        ),
      ],
      child: TextField(
        controller: _reasonController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'سبب الرفض (اختياري)',
          filled: true,
          fillColor: AppColors.inputFill(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
