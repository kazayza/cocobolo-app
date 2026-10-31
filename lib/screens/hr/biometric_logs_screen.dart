import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../services/app_colors.dart';
import '../../services/attendance_admin_service.dart';
import '../../services/design_tokens.dart';
import '../../services/employee_photo_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';

/// سجلات البصمة الخام — مرآة صفحة بلازور BiometricLogs: البصمات كما
/// سجّلها الجهاز قبل أي معالجة، بفلاتر الفترة والاسم وكود البصمة،
/// و«النوع المتوقع» محسوبًا كما في بلازور: أبكر بصمة للكود في يومه
/// (داخل الصفحة المحمّلة) = حضور وما عداها = انصراف.
/// الهوية: مرساة كحلية بثلاث بلاطات إحصائية + شارات حالة ملوّنة،
/// وكل فشل ظاهر مع إعادة محاولة.
class BiometricLogsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const BiometricLogsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<BiometricLogsScreen> createState() => _BiometricLogsScreenState();
}

class _BiometricLogsScreenState extends State<BiometricLogsScreen> {
  static const int _pageSize = 50;

  final AttendanceAdminService _service = AttendanceAdminService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  int _page = 1;

  List<Map<String, dynamic>> _items = [];
  int _totalCount = 0;
  int _totalPages = 1;
  int _todayCount = 0;
  int _employeeCount = 0;
  bool _loading = true;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getRawLogs(
        dateFrom: _ymd(_from),
        dateTo: _ymd(_to),
        searchText:
            _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
        biometricCode:
            _codeController.text.trim().isEmpty
                ? null
                : _codeController.text.trim(),
        pageNumber: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final items =
          (data['items'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        _items = items;
        _totalCount = (data['totalCount'] as num?)?.toInt() ?? items.length;
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        _todayCount = (data['todayCount'] as num?)?.toInt() ?? 0;
        _employeeCount = (data['employeeCount'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
      _preloadPhotos();
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

  /// صور الموظفين المحلية لصفوف الصفحة — على نمط تقرير الحضور:
  /// تُحمَّل إلى ذاكرة الخدمة ثم يُعاد الرسم (محلية فقط دائمًا).
  Future<void> _preloadPhotos() async {
    final service = EmployeePhotoService();
    final ids = <int>{
      for (final item in _items)
        if ((item['EmployeeID'] as num?)?.toInt() != null)
          (item['EmployeeID'] as num).toInt(),
    };
    if (ids.isEmpty) return;
    await Future.wait([for (final id in ids) service.loadFor(id)]);
    if (mounted) setState(() {});
  }

  /// النوع المتوقع كما يحسبه بلازور داخل الصفحة المحمّلة: لكل
  /// (كود، يوم) أبكر وقت هو «حضور» (أول ظهور له فقط) والباقي «انصراف».
  List<bool> _expectedIsIn() {
    final minTime = <String, String>{};
    for (final item in _items) {
      final key = '${item['BiometricCode']}|${item['LogDate']}';
      final t = item['LogTime']?.toString() ?? '';
      if (minTime[key] == null || t.compareTo(minTime[key]!) < 0) {
        minTime[key] = t;
      }
    }
    final seen = <String>{};
    return _items.map((item) {
      final key = '${item['BiometricCode']}|${item['LogDate']}';
      final isEarliest =
          item['LogTime']?.toString() == minTime[key] && !seen.contains(key);
      if (isEarliest) seen.add(key);
      return isEarliest;
    }).toList();
  }

  void _applyFilters() {
    setState(() => _page = 1);
    _load();
  }

  void _clearFilters() {
    final now = DateTime.now();
    setState(() {
      _from = now;
      _to = now;
      _page = 1;
      _searchController.clear();
      _codeController.clear();
    });
    _load();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'rpt_empAttendance'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: const Text('سجلات البصمة الخام'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildAnchor(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFilters(),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
            _buildPagination(),
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
                  Icons.fingerprint_rounded,
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
                      'سجلات البصمة الخام',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'البصمات كما وردت من الجهاز قبل أي معالجة',
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'إجمالي السجلات',
                  '$_totalCount',
                  Icons.list_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'بصمات اليوم',
                  '$_todayCount',
                  Icons.today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statTile(
                  'موظفون في الصفحة',
                  '$_employeeCount',
                  Icons.people_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 17),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.goldLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'تصفية السجلات',
            icon: Icons.filter_alt_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateField('من تاريخ', _from, true)),
              const SizedBox(width: 10),
              Expanded(child: _dateField('إلى تاريخ', _to, false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: _fieldDecoration(
                    'بحث باسم الموظف',
                    Icons.search_rounded,
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration(
                    'كود البصمة',
                    Icons.pin_rounded,
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _applyFilters,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('بحث'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isDark ? AppColors.gold : AppColors.navy,
                    foregroundColor:
                        _isDark ? AppColors.navy : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _clearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('مسح'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text(_isDark),
                    side: BorderSide(
                      color: AppColors.textSecondary(
                        _isDark,
                      ).withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: AppColors.inputFill(_isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: ThemeService().accentColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _dateField(String label, DateTime value, bool isFrom) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary(_isDark),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isFrom),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.textSecondary(_isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('yyyy/MM/dd').format(value),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoading();
    if (_error != null) return AppError(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const AppEmpty(
        message: 'لا توجد بصمات مطابقة',
        icon: Icons.fingerprint_rounded,
      );
    }
    final expected = _expectedIsIn();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildRow(_items[i], expected[i]),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> item, bool isIn) {
    final textTheme = Theme.of(context).textTheme;
    final name = item['EmployeeName']?.toString() ?? '';
    final code = item['BiometricCode']?.toString() ?? '';
    final department = item['Department']?.toString() ?? '';
    final dateRaw = item['LogDate']?.toString() ?? '';
    final date = DateTime.tryParse(dateRaw);
    final time = item['LogTime']?.toString() ?? '';
    final typeColor =
        isIn
            ? (_isDark ? AppColors.successLight : AppColors.success)
            : (_isDark ? AppColors.gold : AppColors.navyLight);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(item),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'كود: $code',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(_isDark),
                      ),
                    ),
                    if (department.isNotEmpty)
                      Text(
                        department,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: isIn ? 'حضور' : 'انصراف',
                    color: typeColor,
                    icon:
                        isIn ? Icons.login_rounded : Icons.logout_rounded,
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: 'الكود $code',
                color: AppColors.neutral,
                icon: Icons.pin_rounded,
                small: true,
              ),
              if (date != null)
                StatusBadge(
                  label:
                      '${DateFormat('yyyy/MM/dd').format(date)} • ${DateFormat('EEEE', 'ar').format(date)}',
                  color: AppColors.neutral,
                  icon: Icons.calendar_today_rounded,
                  small: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> item) {
    final employeeId = (item['EmployeeID'] as num?)?.toInt();
    if (employeeId == null) {
      // بصمة غير مربوطة بموظف — بلاطة بصمة محايدة
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.fingerprint_rounded,
          color: AppColors.gold,
          size: 22,
        ),
      );
    }
    final bytes = EmployeePhotoService().bytesFor(employeeId);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        item['Gender']?.toString() == 'أنثى'
            ? 'assets/images/default_avatar_female.png'
            : 'assets/images/default_avatar_male.png',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPagination() {
    if (_loading || _error != null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        border: Border(top: BorderSide(color: AppColors.divider(_isDark))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed:
                _page > 1
                    ? () {
                      setState(() => _page--);
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('السابق'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'صفحة $_page من $_totalPages • الإجمالي $_totalCount',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed:
                _page < _totalPages
                    ? () {
                      setState(() => _page++);
                      _load();
                    }
                    : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('التالي'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
