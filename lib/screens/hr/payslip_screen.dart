import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/app_colors.dart';
import '../../services/payroll_service.dart';

/// قسيمة الراتب — مطابقة 100% لـ HR/Payroll/PayslipDialog.razor (بلازور هو الأساس)
/// هيدر + 4 إحصائيات + مستحقات + خصومات + دفعات منفصلة + توقيعات + طباعة PDF
class PayslipScreen extends StatefulWidget {
  final int payrollId;
  final String username;
  const PayslipScreen({super.key, required this.payrollId, required this.username});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final PayrollService _service = PayrollService();
  bool _loading = true;
  Map<String, dynamic>? _slip;
  String? _error;

  String _money(dynamic v) => NumberFormat('#,##0.00').format(v is num ? v : num.tryParse('$v') ?? 0);
  Color _statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'paid': return const Color(0xFF10B981);
      case 'approved': return const Color(0xFF2563EB);
      case 'rejected': return const Color(0xFFDC2626);
      case 'pending_review': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  String _statusText(String? s) {
    switch (s?.toLowerCase()) {
      case 'paid': return 'مدفوع';
      case 'approved': return 'معتمد';
      case 'rejected': return 'مرفوض';
      case 'pending_review': return 'قيد المراجعة';
      default: return s ?? '—';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getById(widget.payrollId);
      if (!mounted) return;
      setState(() { _slip = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _print() async {
    if (_slip == null) return;
    final s = _slip!;
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text('قسيمة الراتب #${s['PayrollID'] ?? widget.payrollId}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${s['EmployeeName'] ?? ''} — ${s['PayrollMonth'] ?? ''}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          pw.Text('صافي الراتب: ${_money(s['NetSalary'] ?? s['NetAmount'] ?? 0)} ج', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (fmt) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('قسيمة الراتب', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          if (_slip != null) IconButton(icon: const Icon(Icons.print_rounded), onPressed: _print, tooltip: 'طباعة'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.cairo(color: Colors.red)))
              : _slip == null
                  ? Center(child: Text('القسيمة غير موجودة', style: GoogleFonts.cairo()))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        _header(),
                        const SizedBox(height: 12),
                        _employeeCard(),
                        const SizedBox(height: 12),
                        _stats(),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _earningsCard()),
                          const SizedBox(width: 10),
                          Expanded(child: _deductionsCard()),
                        ]),
                        if ((_slip!['SeparateBonuses'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          _separateCard(),
                        ],
                        const SizedBox(height: 12),
                        _signatures(),
                        const SizedBox(height: 8),
                        Text('تم إنشاء هذه القسيمة بواسطة نظام الرواتب • ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                            style: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 9)),
                      ]),
                    ),
    );
  }

  Widget _header() {
    final s = _slip!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: const Icon(Icons.business_rounded, color: Color(0xFFD4AF37), size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('COCOBOLO', style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
            Text('${s['CompanyAddress'] ?? ''} • ${s['CompanyPhone'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 9)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('قسيمة الراتب الشهرية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          Text('رقم #${s['PayrollID'] ?? widget.payrollId} • ${s['PayrollMonth'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 9)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _statusColor(s['PaymentStatus']), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusText(s['PaymentStatus']), style: GoogleFonts.cairo(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _employeeCard() {
    final s = _slip!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.badge_rounded, size: 14, color: Color(0xFFD4AF37)), const SizedBox(width: 6), Text('بيانات الموظف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12))]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _mini('اسم الموظف', '${s['EmployeeName'] ?? ''}')),
          Expanded(child: _mini('القسم', '${s['Department'] ?? '—'}')),
          Expanded(child: _mini('الوظيفة', '${s['JobTitle'] ?? '—'}')),
          Expanded(child: _mini('الرقم القومي', '${s['NationalId'] ?? '—'}')),
        ]),
        const Divider(height: 20),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('مصدر الحضور: ${s['AttendanceSource'] ?? '—'}', Colors.grey),
          _chip('غياب: ${s['AbsenceDays'] ?? 0} يوم', s['AbsenceDays'] != null && (s['AbsenceDays'] as num) > 0 ? Colors.red : Colors.green),
          _chip('تأخير: ${s['LateMinutesTotal'] ?? 0} د', (s['LateMinutesTotal'] ?? 0) > 0 ? Colors.orange : Colors.green),
          _chip('أيام العمل: ${s['WorkingDaysInMonth'] ?? '—'}', Colors.blue),
        ]),
      ]),
    );
  }

  Widget _mini(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize: 9)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 11)),
    ]);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: GoogleFonts.cairo(color: color.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stats() {
    final s = _slip!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _statBox('إجمالي المستحقات', s['GrossSalary'] ?? s['BasicSalary'] ?? 0, 'الأساسي + الإضافات', const Color(0xFF0F172A)),
        _statBox('إجمالي الخصومات', s['TotalDeductions'] ?? 0, 'غياب + تأخير + سلف', const Color(0xFFDC2626)),
        _statBox('صافي الراتب', s['NetSalary'] ?? s['NetAmount'] ?? 0, 'المبلغ في الكشف', const Color(0xFF059669)),
        _statBox('دفعات منفصلة', s['SeparateTotal'] ?? 0, 'خارج الصافي', const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _statBox(String label, dynamic value, String note, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.85)]), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.85), fontSize: 9)),
        const SizedBox(height: 4),
        Text('${_money(value)} جـ', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        Text(note, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.7), fontSize: 8)),
      ]),
    );
  }

  Widget _earningsCard() {
    final s = _slip!;
    final bonuses = (s['BonusItems'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.add_card_rounded, size: 14, color: Color(0xFF059669)), const SizedBox(width: 6), Text('المستحقات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12))]),
        const SizedBox(height: 10),
        _line('الراتب الأساسي', null, s['BasicSalary'] ?? 0, Colors.black, false),
        ...bonuses.map((b) => _line(b['DetailTypeAr'] ?? b['DetailType'] ?? '', b['Description'], b['Amount'] ?? 0, const Color(0xFF059669), true)),
        if (bonuses.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('لا توجد إضافات', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10))),
      ]),
    );
  }

  Widget _deductionsCard() {
    final s = _slip!;
    final loans = (s['LoanItems'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.remove_circle_rounded, size: 14, color: Color(0xFFDC2626)), const SizedBox(width: 6), Text('الخصومات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12))]),
        const SizedBox(height: 10),
        if ((s['AbsenceDeduction'] ?? 0) != 0) _line('خصم غياب', '${s['AbsenceDays'] ?? 0} يوم', s['AbsenceDeduction'], const Color(0xFFDC2626), true),
        if ((s['LateDeduction'] ?? 0) != 0) _line('خصم تأخير', '${s['LateDisplay'] ?? ''}', s['LateDeduction'], const Color(0xFFDC2626), true),
        ...loans.map((l) => _line(l['DetailTypeAr'] ?? '', l['Description'], l['Amount'] ?? 0, const Color(0xFFDC2626), true)),
        if ((s['TotalDeductions'] ?? 0) == 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('لا توجد خصومات', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10))),
      ]),
    );
  }

  Widget _line(String label, String? sub, dynamic amount, Color color, bool negative) {
    final isPos = color == const Color(0xFF059669);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600)),
          if (sub != null) Text(sub, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 9)),
        ])),
        Text('${isPos ? '+' : '-'} ${_money(amount)} ج', style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _separateCard() {
    final list = (_slip!['SeparateBonuses'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.card_giftcard_rounded, size: 14, color: Color(0xFF2563EB)), const SizedBox(width: 6), Text('دفعات منفصلة خارج الراتب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12))]),
        const SizedBox(height: 8),
        ...list.map((it) => _line(it['DetailTypeAr'] ?? '', it['Description'], it['Amount'], const Color(0xFF2563EB), false)),
      ]),
    );
  }

  Widget _signatures() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Row(children: [const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF64748B)), const SizedBox(width: 6), Text('التوقيعات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 11))]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _signBox('إعداد / HR')),
          Expanded(child: _signBox('مراجعة / حسابات')),
          Expanded(child: _signBox('استلام الموظف')),
        ]),
      ]),
    );
  }

  Widget _signBox(String label) {
    return Column(children: [
      Container(height: 1, color: const Color(0xFF94A3B8)),
      const SizedBox(height: 6),
      Text(label, style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
    ]);
  }
}
