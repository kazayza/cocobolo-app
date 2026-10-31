import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/payroll_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/design_kit.dart';
import 'payroll_status.dart';

/// قسيمة الراتب — وثيقة بهوية التطبيق (بلازور هو الأساس في البيانات):
/// ترويسة كحلية بالشهر والموظف والصافي، ثم الاستحقاقات والخصومات من
/// بنود التفاصيل `details` — وبند الجزاء يظهر بسببه كما هو مكتوب في
/// `DetailDescription` — واحتياطيًا من أعمدة الترويسة التجميعية عند
/// غياب التفاصيل (رواتب قديمة).
class PayslipScreen extends StatefulWidget {
  final int payrollId;
  final String username;
  const PayslipScreen({
    super.key,
    required this.payrollId,
    required this.username,
  });

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final PayrollService _service = PayrollService();
  bool _loading = true;
  Map<String, dynamic>? _slip;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String _money(dynamic v) => NumberFormat('#,##0.00').format(_num(v));

  String _formatMonth(String m) {
    try {
      final parts = m.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy', 'ar').format(d);
    } catch (_) {
      return m;
    }
  }

  // ── بنود التفاصيل ──────────────────────────────────────────────

  List<dynamic> get _details {
    final d = _slip?['details'];
    return d is List ? d : const [];
  }

  /// أنواع الخصم المعروفة في بنود التفاصيل (محرك الـ API وبلازور):
  /// غياب/تأخير/سلف/جزاء بصيغها المختصرة والمطوّلة.
  static bool _isDeductionType(String type) {
    final t = type.toLowerCase();
    return t.contains('absence') ||
        t.contains('late') ||
        t.contains('loan') ||
        t.contains('penalt') ||
        t.contains('deduct');
  }

  List<dynamic> get _deductionDetails => _details
      .where((d) => _isDeductionType('${(d as Map)['DetailType'] ?? ''}'))
      .toList();

  List<dynamic> get _earningDetails => _details
      .where((d) => !_isDeductionType('${(d as Map)['DetailType'] ?? ''}'))
      .toList();

  /// سطر عرض واحد: (التسمية، وصف فرعي اختياري، المبلغ)
  List<(String, String?, double)> get _earningLines {
    final s = _slip!;
    final lines = <(String, String?, double)>[
      ('الراتب الأساسي', null, _num(s['BasicSalary'])),
    ];
    if (_num(s['Allowances']) > 0) {
      lines.add(('البدلات', null, _num(s['Allowances'])));
    }
    if (_num(s['BonusInPayroll']) > 0) {
      lines.add(('حوافز ومكافآت', null, _num(s['BonusInPayroll'])));
    }
    for (final d in _earningDetails) {
      final m = d as Map;
      final desc = '${m['DetailDescription'] ?? ''}'.trim();
      lines.add((
        desc.isNotEmpty ? desc : '${m['DetailType'] ?? 'بند إضافي'}',
        null,
        _num(m['Amount']),
      ));
    }
    return lines;
  }

  List<(String, String?, double)> get _deductionLines {
    final s = _slip!;
    if (_details.isNotEmpty) {
      return _deductionDetails.map((d) {
        final m = d as Map;
        final type = '${m['DetailType'] ?? ''}';
        final desc = '${m['DetailDescription'] ?? ''}'.trim();
        // بند الجزاء: وصفه يحمل السبب نفسه («جزاء: {reason}») فيُعرض
        // كما هو تسميةً للسطر — لا رقمًا مجهولًا.
        if (type.toLowerCase().contains('penalt')) {
          return (
            desc.isNotEmpty ? desc : 'جزاء',
            null,
            _num(m['Amount']),
          );
        }
        return (
          desc.isNotEmpty ? desc : _deductionTypeLabel(type),
          null,
          _num(m['Amount']),
        );
      }).toList();
    }
    // احتياطي الرواتب القديمة بلا تفاصيل: الأعمدة التجميعية
    final lines = <(String, String?, double)>[];
    if (_num(s['AbsenceDeduction']) > 0) {
      lines.add((
        'خصم غياب',
        s['AbsenceDays'] != null ? '${s['AbsenceDays']} يوم' : null,
        _num(s['AbsenceDeduction']),
      ));
    }
    if (_num(s['LateDeduction']) > 0) {
      lines.add((
        'خصم تأخير',
        s['LateMinutesTotal'] != null
            ? '${s['LateMinutesTotal']} دقيقة'
            : null,
        _num(s['LateDeduction']),
      ));
    }
    if (_num(s['LoanDeduction']) > 0) {
      lines.add(('أقساط سلف', null, _num(s['LoanDeduction'])));
    }
    if (_num(s['PenaltyDeduction']) > 0) {
      lines.add(('جزاءات', null, _num(s['PenaltyDeduction'])));
    }
    return lines;
  }

  String _deductionTypeLabel(String type) {
    final t = type.toLowerCase();
    if (t.contains('absence')) return 'خصم غياب';
    if (t.contains('late')) return 'خصم تأخير';
    if (t.contains('loan')) return 'قسط سلفة';
    if (t.contains('penalt')) return 'جزاء';
    return type.isEmpty ? 'خصم' : type;
  }

  // ── المجاميع ───────────────────────────────────────────────────
  // الاختيار المعلن: مجاميع الترويسة (GrossSalary / TotalDeductions)
  // هي الأصل متى وُجدت؛ وغير ذلك تُحسب من أسطر العرض نفسها
  // (الاستحقاقات من حقول الترويسة + بنودها غير الخصمية، والخصومات
  // من أسطر الخصم المعروضة)، حتى لا يختلف المجموع عمّا يراه القارئ.

  double get _grossTotal {
    final s = _slip!;
    if (s['GrossSalary'] != null) return _num(s['GrossSalary']);
    var sum = _earningLines.fold<double>(0, (a, l) => a + l.$3);
    // بنود الاستحقاق التفصيلية قد تُفصّل حافز الترويسة نفسه؛ عند وجود
    // BonusInPayroll لا تُحسب مرتين في الاحتياطي المحسوب
    if (_num(s['BonusInPayroll']) > 0 && _earningDetails.isNotEmpty) {
      sum -= _earningDetails.fold<double>(
        0,
        (a, d) => a + _num((d as Map)['Amount']),
      );
    }
    return sum;
  }

  double get _deductionsTotal {
    final s = _slip!;
    if (s['TotalDeductions'] != null) return _num(s['TotalDeductions']);
    if (_details.isNotEmpty || _deductionLines.isNotEmpty) {
      return _deductionLines.fold<double>(0, (a, l) => a + l.$3);
    }
    return _num(s['Deductions']);
  }

  double get _netSalary {
    final s = _slip!;
    if (s['NetSalary'] != null) return _num(s['NetSalary']);
    if (s['NetAmount'] != null) return _num(s['NetAmount']);
    return _grossTotal - _deductionsTotal;
  }

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
      final data = await _service.getById(widget.payrollId);
      if (!mounted) return;
      setState(() {
        _slip = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// طباعة PDF بنفس حمولة الشاشة تمامًا: بنود الاستحقاق والخصم
  /// (وبنود الجزاء بأسبابها) والمجاميع والصافي الحقيقي.
  Future<void> _print() async {
    if (_slip == null) return;
    final s = _slip!;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'قسيمة الراتب #${s['PayrollID'] ?? widget.payrollId}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${s['EmployeeName'] ?? ''} — ${s['Department'] ?? ''} — ${_formatMonth('${s['PayrollMonth'] ?? ''}')}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 16),
              pw.Text('الاستحقاقات',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              ..._earningLines.map(
                (l) => pw.Text('${l.$1}: ${_money(l.$3)} ج'),
              ),
              pw.SizedBox(height: 12),
              pw.Text('الخصومات',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              if (_deductionLines.isEmpty)
                pw.Text('لا توجد خصومات')
              else
                ..._deductionLines.map(
                  (l) => pw.Text('${l.$1}: ${_money(l.$3)} ج'),
                ),
              pw.SizedBox(height: 16),
              pw.Text('إجمالي الاستحقاقات: ${_money(_grossTotal)} ج'),
              pw.Text('إجمالي الخصومات: ${_money(_deductionsTotal)} ج'),
              pw.SizedBox(height: 8),
              pw.Text(
                'صافي الراتب: ${_money(_netSalary)} ج',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (fmt) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'قسيمة الراتب',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        centerTitle: true,
        actions: [
          if (_slip != null)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              onPressed: _print,
              tooltip: 'طباعة',
            ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _slip == null
                  ? const AppEmpty(message: 'القسيمة غير موجودة')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _headerBand(),
                          const SizedBox(height: 12),
                          _employeeCard(),
                          const SizedBox(height: 12),
                          _earningsCard(),
                          const SizedBox(height: 12),
                          _deductionsCard(),
                          const SizedBox(height: 12),
                          _totalsCard(),
                          if ((_slip!['SeparateBonuses'] as List?)
                                  ?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 12),
                            _separateCard(),
                          ],
                          const SizedBox(height: 12),
                          _signatures(),
                          const SizedBox(height: 10),
                          Text(
                            'تم إنشاء هذه القسيمة بواسطة نظام الرواتب • ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary(_isDark),
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  /// الترويسة الكحلية للوثيقة: العنوان والشهر والموظف وقسمه،
  /// وشارة الحالة، والصافي كبيرًا بالذهبي فوق الكحلي.
  Widget _headerBand() {
    final s = _slip!;
    final textTheme = Theme.of(context).textTheme;
    final statusKey = payrollStatusKey(s);
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.gold,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قسيمة راتب',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatMonth('${s['PayrollMonth'] ?? ''}')} • قسيمة #${s['PayrollID'] ?? widget.payrollId}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: payrollStatusLabel(
                  statusKey,
                  raw: '${s['PaymentStatus'] ?? ''}',
                ),
                color: payrollStatusColor(statusKey, _isDark),
                filled: true,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s['EmployeeName'] ?? ''}',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ('${s['Department'] ?? ''}'.isNotEmpty ||
                        '${s['JobTitle'] ?? ''}'.isNotEmpty)
                      Text(
                        [
                          '${s['JobTitle'] ?? ''}',
                          '${s['Department'] ?? ''}',
                        ].where((x) => x.isNotEmpty).join(' • '),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.goldLight,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'صافي الراتب',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AmountText(
                    value: '${_money(_netSalary)} جـ',
                    color: AppColors.gold,
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _employeeCard() {
    final s = _slip!;
    final hasAttendance = s['AbsenceDays'] != null ||
        s['LateMinutesTotal'] != null ||
        s['WorkingDaysInMonth'] != null;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'بيانات الموظف',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mini('اسم الموظف', '${s['EmployeeName'] ?? ''}')),
              Expanded(child: _mini('القسم', '${s['Department'] ?? '—'}')),
              Expanded(child: _mini('الوظيفة', '${s['JobTitle'] ?? '—'}')),
            ],
          ),
          if (hasAttendance) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (s['WorkingDaysInMonth'] != null)
                  _chip(
                    'أيام العمل: ${s['WorkingDaysInMonth']}',
                    _isDark ? AppColors.infoLight : AppColors.info,
                  ),
                if (s['AbsenceDays'] != null)
                  _chip(
                    'غياب: ${s['AbsenceDays']} يوم',
                    _num(s['AbsenceDays']) > 0
                        ? (_isDark ? AppColors.errorLight : AppColors.error)
                        : (_isDark
                            ? AppColors.successLight
                            : AppColors.success),
                  ),
                if (s['LateMinutesTotal'] != null)
                  _chip(
                    'تأخير: ${s['LateMinutesTotal']} دقيقة',
                    _num(s['LateMinutesTotal']) > 0
                        ? (_isDark
                            ? AppColors.warningLight
                            : AppColors.warning)
                        : (_isDark
                            ? AppColors.successLight
                            : AppColors.success),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary(_isDark),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: AppColors.text(_isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _earningsCard() {
    final accent = _isDark ? AppColors.successLight : AppColors.success;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'الاستحقاقات',
            icon: Icons.add_card_rounded,
            accent: accent,
          ),
          const SizedBox(height: 8),
          ..._earningLines.map((l) => _line(l.$1, l.$2, l.$3, accent, '+')),
        ],
      ),
    );
  }

  Widget _deductionsCard() {
    final accent = _isDark ? AppColors.errorLight : AppColors.error;
    final lines = _deductionLines;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'الخصومات',
            icon: Icons.remove_circle_rounded,
            accent: accent,
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'لا توجد خصومات',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                    ),
              ),
            )
          else
            ...lines.map((l) => _line(l.$1, l.$2, l.$3, accent, '-')),
        ],
      ),
    );
  }

  Widget _line(
    String label,
    String? sub,
    double amount,
    Color color,
    String sign,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$sign ${_money(amount)} جـ',
            style: textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة المجاميع: الإجمالي والخصومات، والصافي بارزًا — ذهبيًا في
  /// الليلي وكحليًا في النهاري (الذهبي نصًا فوق سطح فاتح يخالف
  /// قانون التباين؛ الصافي الذهبي الكبير يعيش في الترويسة الكحلية).
  Widget _totalsCard() {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        children: [
          _totalRow('إجمالي الاستحقاقات', _grossTotal),
          const SizedBox(height: 8),
          _totalRow('إجمالي الخصومات', _deductionsTotal),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.divider(_isDark)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'صافي الراتب',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              AmountText(
                value: '${_money(_netSalary)} جـ',
                color: _isDark ? AppColors.gold : AppColors.navy,
                size: 21,
              ),
            ],
          ),
          if (_slip!['PaymentStatus'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'حالة الدفع',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                const Spacer(),
                StatusBadge(
                  label: payrollStatusLabel(
                    payrollStatusKey(_slip!),
                    raw: '${_slip!['PaymentStatus']}',
                  ),
                  color:
                      payrollStatusColor(payrollStatusKey(_slip!), _isDark),
                  small: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary(_isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '${_money(value)} جـ',
          style: textTheme.titleSmall?.copyWith(
            color: AppColors.text(_isDark),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _separateCard() {
    final list = (_slip!['SeparateBonuses'] as List?) ?? [];
    final accent = _isDark ? AppColors.infoLight : AppColors.info;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'دفعات منفصلة خارج الراتب',
            icon: Icons.card_giftcard_rounded,
            accent: accent,
          ),
          const SizedBox(height: 8),
          ...list.map(
            (it) => _line(
              '${(it as Map)['DetailDescription'] ?? it['DetailType'] ?? ''}',
              null,
              _num(it['Amount']),
              accent,
              '+',
            ),
          ),
        ],
      ),
    );
  }

  Widget _signatures() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        children: [
          const AppSectionHeader(
            title: 'التوقيعات',
            icon: Icons.edit_note_rounded,
            accent: AppColors.neutral,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _signBox('إعداد / HR')),
              const SizedBox(width: 12),
              Expanded(child: _signBox('مراجعة / حسابات')),
              const SizedBox(width: 12),
              Expanded(child: _signBox('استلام الموظف')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signBox(String label) {
    return Column(
      children: [
        Container(height: 1, color: AppColors.divider(_isDark)),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
