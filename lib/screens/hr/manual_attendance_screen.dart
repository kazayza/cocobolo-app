import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../services/app_colors.dart';
import '../../services/attendance_admin_service.dart';
import '../../services/design_tokens.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/employee_picker.dart';
import '../../widgets/identity_dialog.dart';
import 'attendance_status.dart';

/// الحضور اليدوي اليومي — مرآة نموذج بلازور ManualDailyAttendancePage:
/// اختيار التاريخ والموظف ثم «تحميل السجل» ضمنيًا عند أي تغيير،
/// فإما سجل قائم يُعبَّأ في المحرر أو سجل جديد؛ حالات بلازور الثماني
/// بقيمها المخزنة، وأوقات معطّلة لحالات اللاوقت، وسبب إدخال/تعديل
/// إلزامي، ومعاينة حية للحالة النهائية والساعات والتأخير والخروج
/// المبكر على نافذة الشيفت المحسومة من الخادم، وحفظ = إدراج/تحديث،
/// وحذف عند تحميل سجل، وقائمة سجلات اليوم تُحمّل صفوفها في المحرر.
/// كل وحدات التحكم ملك حالة هذه الشاشة وتُحرَّر في dispose الخاصة
/// بها، وكل فشل ظاهر برسالة الخادم — لا ابتلاع صامت.
class ManualAttendanceScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialEmployeeId;
  final DateTime? initialDate;

  const ManualAttendanceScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialEmployeeId,
    this.initialDate,
  });

  @override
  State<ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final AttendanceAdminService _service = AttendanceAdminService();
  final TextEditingController _timeInController = TextEditingController();
  final TextEditingController _timeOutController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  late DateTime _date;
  EmployeeOption? _employee;
  List<EmployeeOption> _employeeOptions = [];
  bool _employeesLoading = false;
  String? _employeesError;

  bool _loadingRecord = false;
  String? _recordError;
  Map<String, dynamic>? _employeeInfo;
  Map<String, dynamic>? _loadedRecord;
  String _shiftStart = '08:00';
  String _shiftEnd = '17:00';

  String _status = 'حاضر';
  bool _saving = false;
  bool _deleting = false;

  List<Map<String, dynamic>> _dayRows = [];
  bool _dayLoading = false;
  String? _dayError;

  bool get _isDark => ThemeService().isDarkMode;
  bool get _noTime => !attendanceStatusNeedsTime(_status);
  int? get _loadedId =>
      (_loadedRecord?['AttendanceID'] as num?)?.toInt();
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);
  String? get _biometricCode =>
      _employeeInfo?['BiometricCode']?.toString() ??
      _loadedRecord?['BiometricCode']?.toString();

  bool get _canSave =>
      !_saving &&
      !_deleting &&
      _employee != null &&
      _reasonController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _loadEmployees();
    _loadDay();
    final initialId = widget.initialEmployeeId;
    if (initialId != null) {
      _loadRecord(initialId, _date);
    }
  }

  @override
  void dispose() {
    _timeInController.dispose();
    _timeOutController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ── التحميل ──────────────────────────────────────────────────

  Future<void> _loadEmployees() async {
    setState(() {
      _employeesLoading = true;
      _employeesError = null;
    });
    try {
      final options = await fetchActiveEmployeeOptions();
      if (!mounted) return;
      setState(() {
        _employeeOptions = options;
        _employeesLoading = false;
        // موظف مثبّت من سياق خارجي ولم يصل سجله بعد: أكمل الاسم
        // من قائمة المنتقي متى توفر دون مساس بسجل محمّل
        final current = _employee;
        if (current != null && current.name.isEmpty) {
          for (final o in options) {
            if (o.id == current.id) _employee = o;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeesError = 'فشل تحميل قائمة الموظفين';
        _employeesLoading = false;
      });
    }
  }

  /// تحميل سجل (موظف، يوم) إلى المحرر — قلب سير عمل بلازور:
  /// سجل قائم يُعبّأ (الأوقات والحالة) أو غيابه = سجل جديد،
  /// والسبب يبدأ فارغًا دائمًا كما يفرغه بلازور عند كل تحميل.
  Future<void> _loadRecord(int employeeId, DateTime date) async {
    setState(() {
      _loadingRecord = true;
      _recordError = null;
    });
    try {
      final data = await _service.getManualRecord(
        employeeId,
        DateFormat('yyyy-MM-dd').format(date),
      );
      if (!mounted) return;
      final employee =
          data['employee'] is Map
              ? Map<String, dynamic>.from(data['employee'] as Map)
              : null;
      final record =
          data['record'] is Map
              ? Map<String, dynamic>.from(data['record'] as Map)
              : null;
      final shift =
          data['shift'] is Map
              ? Map<String, dynamic>.from(data['shift'] as Map)
              : null;
      setState(() {
        _employeeInfo = employee;
        if (employee != null) {
          _employee = EmployeeOption(
            id: employeeId,
            name: employee['FullName']?.toString() ?? _employee?.name ?? '',
            department: employee['Department']?.toString() ?? '',
          );
        }
        if (shift != null) {
          _shiftStart =
              attendanceNormalizeTime(shift['StartTime']) ?? _shiftStart;
          _shiftEnd = attendanceNormalizeTime(shift['EndTime']) ?? _shiftEnd;
        }
        _loadedRecord = record;
        if (record != null) {
          final stored = record['Status']?.toString().trim() ?? '';
          _status = stored.isEmpty ? 'حاضر' : stored;
          _timeInController.text =
              attendanceNormalizeTime(record['TimeIn']) ?? '';
          _timeOutController.text =
              attendanceNormalizeTime(record['TimeOut']) ?? '';
        } else {
          _status = 'حاضر';
          _timeInController.clear();
          _timeOutController.clear();
        }
        _reasonController.clear();
        _loadingRecord = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _recordError = e.message;
        _loadingRecord = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recordError = 'فشل الاتصال بالخادم عند تحميل السجل';
        _loadingRecord = false;
      });
    }
  }

  Future<void> _loadDay() async {
    setState(() {
      _dayLoading = true;
      _dayError = null;
    });
    try {
      final rows = await _service.getManualDay(_dateStr);
      if (!mounted) return;
      setState(() {
        _dayRows = rows;
        _dayLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _dayError = e.message;
        _dayLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dayError = 'فشل الاتصال بالخادم عند جلب سجلات اليوم';
        _dayLoading = false;
      });
    }
  }

  // ── التفاعلات ────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _loadDay();
    final emp = _employee;
    if (emp != null) _loadRecord(emp.id, picked);
  }

  Future<void> _pickEmployee() async {
    final picked = await showEmployeePickerSheet(
      context,
      employees: _employeeOptions,
      title: 'اختيار الموظف',
    );
    if (picked == null) return;
    setState(() => _employee = picked);
    _loadRecord(picked.id, _date);
  }

  void _resetEditor() {
    setState(() {
      _employee = null;
      _employeeInfo = null;
      _loadedRecord = null;
      _recordError = null;
      _status = 'حاضر';
      _shiftStart = '08:00';
      _shiftEnd = '17:00';
      _timeInController.clear();
      _timeOutController.clear();
      _reasonController.clear();
    });
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? (_isDark ? AppColors.errorLight : AppColors.error) : null,
      ),
    );
  }

  /// وقت من حقل نصي: فارغ = null، وصيغة غير صالحة ترفع رسالة عربية.
  String? _fieldTime(TextEditingController c, String label) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final minutes = attendanceParseMinutes(raw);
    if (minutes == null) {
      throw FormatException('صيغة $label غير صحيحة — استخدم HH:mm');
    }
    return attendanceFormatMinutes(minutes);
  }

  Future<void> _save() async {
    final emp = _employee;
    if (emp == null) {
      _snack('اختر الموظف أولًا', error: true);
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _snack('سبب الإدخال / التعديل إلزامي', error: true);
      return;
    }
    final String? timeIn;
    final String? timeOut;
    try {
      timeIn = _noTime ? null : _fieldTime(_timeInController, 'وقت الحضور');
      timeOut =
          _noTime ? null : _fieldTime(_timeOutController, 'وقت الانصراف');
    } on FormatException catch (e) {
      _snack(e.message, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> res;
      final loadedId = _loadedId;
      if (loadedId != null) {
        res = await _service.updateManual(
          loadedId,
          timeIn: timeIn,
          timeOut: timeOut,
          status: _status,
          editReason: reason,
        );
      } else {
        res = await _service.createManual(
          employeeId: emp.id,
          logDate: _dateStr,
          timeIn: timeIn,
          timeOut: timeOut,
          status: _status,
          editReason: reason,
        );
      }
      if (!mounted) return;
      _snack(res['message']?.toString() ?? 'تم حفظ السجل بنجاح');
      await Future.wait([_loadRecord(emp.id, _date), _loadDay()]);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final loadedId = _loadedId;
    if (loadedId == null || _deleting) return;
    final confirmed = await showIdentityConfirmDialog(
      context: context,
      icon: Icons.delete_rounded,
      title: 'حذف سجل الحضور',
      message:
          'سيُحذف سجل حضور ${_employee?.name ?? ''} بتاريخ '
          '${DateFormat('yyyy/MM/dd').format(_date)} نهائيًا.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      final message = await _service.deleteManual(loadedId);
      if (!mounted) return;
      _snack(message);
      final emp = _employee;
      setState(() {
        _loadedRecord = null;
        _status = 'حاضر';
        _timeInController.clear();
        _timeOutController.clear();
        _reasonController.clear();
      });
      await _loadDay();
      if (emp != null) await _loadRecord(emp.id, _date);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _loadDayRow(Map<String, dynamic> row) {
    final employeeId = (row['EmployeeID'] as num?)?.toInt();
    if (employeeId == null) {
      _snack('هذا السجل غير مرتبط بموظف معروف', error: true);
      return;
    }
    setState(() {
      _employee = EmployeeOption(
        id: employeeId,
        name: row['EmployeeName']?.toString() ?? '',
        department: row['Department']?.toString() ?? '',
      );
    });
    _loadRecord(employeeId, _date);
  }

  // ── المعاينة الحية ───────────────────────────────────────────

  /// (الحالة النهائية، ساعات العمل، التأخير، الخروج المبكر) محسوبة
  /// من الحقول الحالية على نافذة الشيفت المحمّلة — قاعدة الليل:
  /// انصراف قبل الحضور يعني يومًا تاليًا (+24 ساعة).
  (String, String, String, String) _preview() {
    if (_noTime) {
      return (attendanceStatusLabel(_status), '—', '0 دقيقة', '0 دقيقة');
    }
    final inMin = attendanceParseMinutes(_timeInController.text);
    final outMin = attendanceParseMinutes(_timeOutController.text);
    final shiftStart = attendanceParseMinutes(_shiftStart) ?? 480;
    final shiftEnd = attendanceParseMinutes(_shiftEnd) ?? 1020;
    if (inMin == null) {
      return ('—', '—', '0 دقيقة', '0 دقيقة');
    }
    final late = inMin > shiftStart ? inMin - shiftStart : 0;
    var early = 0;
    String hours = '—';
    if (outMin != null) {
      var effectiveOut = outMin;
      if (effectiveOut < inMin) effectiveOut += 1440;
      hours = '${((effectiveOut - inMin) / 60).toStringAsFixed(2)} ساعة';
      final effectiveShiftEnd = shiftEnd < shiftStart ? shiftEnd + 1440 : shiftEnd;
      final outOnShiftDay = outMin < inMin ? outMin + 1440 : outMin;
      early =
          outOnShiftDay < effectiveShiftEnd
              ? effectiveShiftEnd - outOnShiftDay
              : 0;
    }
    final status =
        late > 0
            ? 'متأخر'
            : early > 0
            ? 'خروج مبكر'
            : 'حاضر';
    return (
      attendanceStatusLabel(status),
      hours,
      '$late دقيقة',
      '$early دقيقة',
    );
  }

  // ── البناء ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'rpt_empAttendance'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: const Text('الحضور اليدوي اليومي'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnchor(),
                    const SizedBox(height: 12),
                    _buildSelectorCard(),
                    const SizedBox(height: 12),
                    _buildEditorCard(),
                    const SizedBox(height: 12),
                    _buildDayCard(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnchor() {
    final textTheme = Theme.of(context).textTheme;
    final isExisting = _loadedRecord != null;
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
                  Icons.edit_calendar_rounded,
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
                      'الحضور اليدوي اليومي',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'إدخال أو تعديل سجل حضور موظف في يوم محدد',
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label:
                    '${DateFormat('yyyy/MM/dd').format(_date)} • ${DateFormat('EEEE', 'ar').format(_date)}',
                color: AppColors.gold,
                icon: Icons.calendar_today_rounded,
                small: true,
              ),
              StatusBadge(
                label: isExisting ? 'سجل قائم' : 'سجل جديد',
                color:
                    isExisting
                        ? AppColors.successLight
                        : AppColors.infoLight,
                icon:
                    isExisting
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_rounded,
                small: true,
              ),
              StatusBadge(
                label: 'الشيفت $_shiftStart – $_shiftEnd',
                color: AppColors.neutralLight,
                icon: Icons.schedule_rounded,
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorCard() {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'الموظف والتاريخ',
            icon: Icons.person_search_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            'التاريخ *',
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary(_isDark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 19,
                    color: AppColors.textSecondary(_isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${DateFormat('yyyy/MM/dd').format(_date)} — ${DateFormat('EEEE', 'ar').format(_date)}',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.text(_isDark),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_employeesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppLoading(),
            )
          else if (_employeesError != null)
            AppError(message: _employeesError!, onRetry: _loadEmployees)
          else
            EmployeePickerField(
              label: 'الموظف *',
              selected: _employee,
              onTap: _pickEmployee,
            ),
          if (_loadingRecord) ...[
            const SizedBox(height: 12),
            const AppLoading(message: 'جارٍ تحميل السجل...'),
          ],
          if (_recordError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: (_isDark ? AppColors.errorLight : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 17,
                    color: _isDark ? AppColors.errorLight : AppColors.error,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _recordError!,
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            _isDark ? AppColors.errorLight : AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _employee == null
                            ? null
                            : () => _loadRecord(_employee!.id, _date),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ],
          if (_employee != null && !_loadingRecord) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    _isDark
                        ? AppColors.card(_isDark)
                        : AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 18,
                    color: AppColors.textSecondary(_isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _biometricCode != null && _biometricCode!.isNotEmpty
                          ? 'كود البصمة: $_biometricCode'
                          : 'لا يوجد كود بصمة لهذا الموظف — لا يمكن حفظ السجل',
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            _biometricCode != null &&
                                    _biometricCode!.isNotEmpty
                                ? AppColors.text(_isDark)
                                : (_isDark
                                    ? AppColors.warningLight
                                    : AppColors.warning),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorCard() {
    final textTheme = Theme.of(context).textTheme;
    // قيمة مخزنة خارج قائمة الإدخال (مثل «عطلة أسبوعية») يجب أن تبقى
    // في عناصر القائمة المنسدلة وإلا انهارت — درس شاشة التعديل الحمراء
    final dropdownValues = <String>[
      for (final def in attendanceStatuses) def.value,
      if (!attendanceStatuses.any((d) => d.value == _status)) _status,
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'بيانات الحضور',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            'الحالة *',
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary(_isDark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                attendanceStatuses.map((def) {
                  return ChoiceChip(
                    label: Text(def.label),
                    selected: _status == def.value,
                    onSelected:
                        (_) => setState(() => _status = def.value),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // مفتاح بالحالة الحالية: اختيار الرقائق يبدّل القيمة من
            // خارج الحقل، فيُعاد إنشاء حالته بالقيمة الجديدة
            key: ValueKey(_status),
            initialValue: dropdownValues.contains(_status) ? _status : null,
            items:
                dropdownValues
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(attendanceStatusLabel(v)),
                      ),
                    )
                    .toList(),
            onChanged:
                (v) => setState(() => _status = v ?? _status),
            decoration: InputDecoration(
              labelText: 'حالة الحضور *',
              filled: true,
              fillColor: AppColors.inputFill(_isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(
              label: attendanceStatusLabel(_status),
              color: attendanceStatusColor(_status, _isDark),
              icon: attendanceStatusIcon(_status),
              small: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _timeField(
                  label: 'وقت الحضور',
                  controller: _timeInController,
                  enabled: !_noTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timeField(
                  label: 'وقت الانصراف',
                  controller: _timeOutController,
                  enabled: !_noTime,
                ),
              ),
            ],
          ),
          if (_noTime) ...[
            const SizedBox(height: 8),
            Text(
              'الحالة الحالية لا تحتاج إلى إدخال وقت حضور أو انصراف',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'سبب الإدخال / التعديل *',
              hintText: 'اشرح سبب الإدخال اليدوي أو التعديل...',
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
            ),
          ),
          const SizedBox(height: 14),
          _buildPreview(),
        ],
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
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
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.datetime,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'HH:mm',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.schedule_rounded, size: 19),
              onPressed: enabled ? () => _pickTime(controller) : null,
              tooltip: 'اختيار الوقت',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = attendanceParseMinutes(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime:
          current == null
              ? const TimeOfDay(hour: 8, minute: 0)
              : TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
    );
    if (picked != null) {
      setState(() {
        controller.text = attendanceFormatMinutes(
          picked.hour * 60 + picked.minute,
        );
      });
    }
  }

  Widget _buildPreview() {
    final (status, hours, late, early) = _preview();
    final textTheme = Theme.of(context).textTheme;
    Widget cell(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(_isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.text(_isDark),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 16,
                color: AppColors.textSecondary(_isDark),
              ),
              const SizedBox(width: 6),
              Text(
                'معاينة النتيجة',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cell('الحالة النهائية', status)),
              Expanded(child: cell('ساعات العمل', hours)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cell('التأخير المتوقع', late)),
              Expanded(child: cell('الخروج المبكر المتوقع', early)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard() {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'سجلات اليوم',
            subtitle: DateFormat('yyyy/MM/dd').format(_date),
            icon: Icons.list_alt_rounded,
            trailing: IconButton(
              onPressed: _dayLoading ? null : _loadDay,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              tooltip: 'تحديث',
            ),
          ),
          const SizedBox(height: 10),
          if (_dayLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AppLoading(),
            )
          else if (_dayError != null)
            AppError(message: _dayError!, onRetry: _loadDay)
          else if (_dayRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا توجد سجلات يدوية في هذا اليوم',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _dayRows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildDayRow(_dayRows[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDayRow(Map<String, dynamic> row) {
    final textTheme = Theme.of(context).textTheme;
    final status = row['Status']?.toString() ?? '';
    final isLoaded =
        _loadedId != null &&
        (row['AttendanceID'] as num?)?.toInt() == _loadedId;
    final inOut = [
      if (attendanceNormalizeTime(row['TimeIn']) != null)
        'حضور ${attendanceNormalizeTime(row['TimeIn'])}',
      if (attendanceNormalizeTime(row['TimeOut']) != null)
        'انصراف ${attendanceNormalizeTime(row['TimeOut'])}',
    ].join(' • ');
    return InkWell(
      onTap: () => _loadDayRow(row),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isLoaded
                  ? ThemeService().accentColor.withValues(alpha: 0.10)
                  : (_isDark
                      ? AppColors.card(_isDark)
                      : AppColors.inputFill(_isDark)),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              isLoaded
                  ? Border.all(color: ThemeService().accentColor)
                  : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['EmployeeName']?.toString() ?? '—',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((row['Department']?.toString() ?? '').isNotEmpty)
                        row['Department'].toString(),
                      if (inOut.isNotEmpty) inOut,
                    ].join(' • '),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: attendanceStatusLabel(status),
              color: attendanceStatusColor(status, _isDark),
              icon: attendanceStatusIcon(status),
              small: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                disabledBackgroundColor: AppColors.gold.withValues(
                  alpha: 0.45,
                ),
                disabledForegroundColor: AppColors.navy.withValues(
                  alpha: 0.6,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon:
                  _saving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navy,
                        ),
                      )
                      : const Icon(Icons.save_rounded, size: 19),
              label: const Text(
                'حفظ السجل',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: _saving || _deleting ? null : _resetEditor,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon: const Icon(Icons.add_circle_rounded, size: 18),
              label: const Text(
                'سجل جديد',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          if (_loadedRecord != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _saving || _deleting ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorLight,
                  side: const BorderSide(color: AppColors.errorLight),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                icon:
                    _deleting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.errorLight,
                          ),
                        )
                        : const Icon(Icons.delete_rounded, size: 18),
                label: const Text(
                  'حذف السجل الحالي',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
