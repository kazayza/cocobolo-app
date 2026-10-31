import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/exemption_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import '../widgets/employee_picker.dart';
import 'hr/exemption_status.dart';

/// إنشاء استثناء يومي — مرآة نموذجي بلازور:
/// • وضع المدير (ExemptionsPage): اختيار الموظف، سبب بإكمال حر من
///   المقترحات الأربعة، خصم صريح، ملاحظات — ويولد «معتمدًا» فورًا.
/// • وضع الموظف (MyExemptionsPage): طلب لنفسه فقط، السبب اختيار من
///   المقترحات الأربعة حصرًا؛ الإذن والانصراف المبكر بالساعات حتمًا،
///   ولا اختيار للخصم — ويولد «قيد الاعتماد».
/// الموظف يُرسَل بمعرّفه (employeeId) ويحلّ الخادم بصمته منه.
class AddExemptionScreen extends StatefulWidget {
  final String username;

  const AddExemptionScreen({super.key, required this.username});

  @override
  State<AddExemptionScreen> createState() => _AddExemptionScreenState();
}

class _AddExemptionScreenState extends State<AddExemptionScreen> {
  final ExemptionService _service = ExemptionService();
  final TextEditingController _reasonController = TextEditingController();
  final FocusNode _reasonFocus = FocusNode();
  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late final bool _managerMode;
  EmployeeOption? _employee;
  bool _employeesLoading = false;
  String? _employeesError;
  List<EmployeeOption> _employeeOptions = [];

  DateTime _date = DateTime.now();
  String _reason = '';
  bool _isFullDay = true;
  double _hours = 1;
  bool? _isDeducted; // null = افتراضي النوع (وضع المدير)
  bool _deductedTouched = false;
  bool _submitting = false;

  bool get _isDark => ThemeService().isDarkMode;

  /// الإذن والانصراف المبكر بالساعات حتمًا في وضع الموظف (قاعدة بلازور).
  bool get _forcedHourly =>
      !_managerMode &&
      (exemptionIsPermission(_reason) || exemptionIsEarlyLeave(_reason));

  bool get _effectiveFullDay => _forcedHourly ? false : _isFullDay;

  @override
  void initState() {
    super.initState();
    _managerMode = PermissionService().canAddExemptions;
    if (_managerMode) _loadEmployees();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _reasonFocus.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeesError = 'فشل تحميل قائمة الموظفين';
        _employeesLoading = false;
      });
    }
  }

  void _onReasonChanged(String value) {
    setState(() {
      _reason = value;
      // طلب الموظف: المأمورية يوم كامل افتراضيًا
      if (!_managerMode && exemptionIsErrand(value)) _isFullDay = true;
      // وضع المدير: الخصم يتبع تصنيف النوع ما لم يلمسه المستخدم
      if (_managerMode && !_deductedTouched) {
        _isDeducted = exemptionDefaultIsDeducted(value);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickEmployee() async {
    final picked = await showEmployeePickerSheet(
      context,
      employees: _employeeOptions,
      title: 'اختيار الموظف',
    );
    if (picked != null) setState(() => _employee = picked);
  }

  Future<void> _submit() async {
    final reason = _managerMode ? _reasonController.text.trim() : _reason;
    if (_managerMode && _employee == null) {
      _snack('اختر الموظف أولًا', error: true);
      return;
    }
    if (reason.isEmpty) {
      _snack('أدخل سبب الاستثناء', error: true);
      return;
    }
    if (!_effectiveFullDay && (_hours < 0.5 || _hours > 12)) {
      _snack('عدد الساعات يجب أن يكون بين 0.5 و12', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _service.create(
        employeeId: _managerMode ? _employee!.id : null,
        exemptionDate: DateFormat('yyyy-MM-dd').format(_date),
        reasonCode: reason,
        description: _descriptionController.text,
        isFullDay: _effectiveFullDay,
        hours: _effectiveFullDay ? null : _hours,
        isDeducted: _managerMode
            ? (_isDeducted ?? exemptionDefaultIsDeducted(reason))
            : null,
        notes: _managerMode ? _notesController.text : null,
      );
      if (!mounted) return;
      _snack(res['message']?.toString() ?? 'تم حفظ الاستثناء بنجاح');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text(_managerMode ? 'إضافة استثناء' : 'طلب استثناء جديد'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTargetSection(),
                  const SizedBox(height: 12),
                  _buildReasonSection(),
                  const SizedBox(height: 12),
                  _buildDetailsSection(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.text(_isDark),
          ),
    );
  }

  Widget _buildTargetSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('الموظف والتاريخ'),
          const SizedBox(height: 12),
          if (_managerMode) ...[
            if (_employeesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: AppLoading(),
              )
            else if (_employeesError != null)
              AppError(message: _employeesError!, onRetry: _loadEmployees)
            else
              InkWell(
                onTap: _pickEmployee,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'الموظف *',
                    filled: true,
                    fillColor: AppColors.inputFill(_isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  child: Text(
                    _employee == null
                        ? 'اختر الموظف'
                        : '${_employee!.name}'
                            '${_employee!.department.isNotEmpty ? ' — ${_employee!.department}' : ''}',
                  ),
                ),
              ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: _isDark ? AppColors.goldLight : AppColors.navy,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'الطلب لنفسك — لا يمكن الطلب لموظف آخر',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary(_isDark),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'تاريخ الاستثناء *',
                filled: true,
                fillColor: AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: const Icon(Icons.calendar_month_rounded),
              ),
              child: Text(
                '${DateFormat('yyyy/MM/dd').format(_date)} — ${DateFormat('EEEE', 'ar').format(_date)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('السبب والمدة'),
          const SizedBox(height: 12),
          if (_managerMode)
            RawAutocomplete<String>(
              textEditingController: _reasonController,
              focusNode: _reasonFocus,
              optionsBuilder: (value) {
                final q = value.text.trim();
                if (q.isEmpty) return exemptionReasonSuggestions;
                return exemptionReasonSuggestions
                    .where((s) => s.contains(q));
              },
              onSelected: _onReasonChanged,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: _onReasonChanged,
                  decoration: InputDecoration(
                    labelText: 'سبب الاستثناء *',
                    hintText: 'اكتب السبب أو اختر من المقترحات',
                    filled: true,
                    fillColor: AppColors.inputFill(_isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 220, maxWidth: 320),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: exemptionReasonSuggestions.map((s) {
                return ChoiceChip(
                  label: Text(s),
                  selected: _reason == s,
                  onSelected: (_) => _onReasonChanged(s),
                );
              }).toList(),
            ),
          if (_reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: exemptionDefaultIsDeducted(_reason)
                    ? AppColors.error.withValues(alpha: _isDark ? 0.16 : 0.08)
                    : AppColors.success
                        .withValues(alpha: _isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                exemptionReasonEffectText(_reason),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: exemptionDefaultIsDeducted(_reason)
                          ? (_isDark ? AppColors.errorLight : AppColors.error)
                          : (_isDark
                              ? AppColors.successLight
                              : AppColors.success),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_forcedHourly)
            Text(
              'هذا النوع بالساعات حتمًا (لا يوم كامل)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
            )
          else
            Row(
              children: [
                const Expanded(child: Text('يوم كامل')),
                Switch(
                  value: _isFullDay,
                  onChanged: (v) => setState(() => _isFullDay = v),
                ),
              ],
            ),
          if (!_effectiveFullDay) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('عدد الساعات'),
                const Spacer(),
                IconButton(
                  onPressed:
                      _hours > 0.5 ? () => setState(() => _hours -= 0.5) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                Text(
                  _hours.toStringAsFixed(_hours % 1 == 0 ? 0 : 1),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  onPressed:
                      _hours < 12 ? () => setState(() => _hours += 0.5) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
          ],
          if (_managerMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('يُخصم من الراتب'),
                      Text(
                        'الافتراضي يتبع نوع السبب — عدّله صراحة عند الحاجة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary(_isDark),
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDeducted ?? exemptionDefaultIsDeducted(_reason),
                  onChanged: (v) => setState(() {
                    _isDeducted = v;
                    _deductedTouched = true;
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('التفاصيل'),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'الوصف',
              filled: true,
              fillColor: AppColors.inputFill(_isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_managerMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                filled: true,
                fillColor: AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
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
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.navy,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 19),
          label: Text(
            _managerMode ? 'حفظ الاستثناء' : 'إرسال الطلب',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
