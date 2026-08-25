import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/cashbox_service.dart';
import '../../services/personal_account_service.dart';

/// ─────────────────────────────────────────────────────────────
/// 💱 إضافة حركة لحساب شخصي (قرض دخل / تسديد)
///  - LoanIn = قبض (فلوس دخلت للحساب)
///  - LoanRepayment = صرف (تسديد من الحساب)
/// ─────────────────────────────────────────────────────────────
class PersonalAccountTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  final String? username;

  const PersonalAccountTransactionScreen({super.key, required this.account, this.username});

  @override
  State<PersonalAccountTransactionScreen> createState() => _PersonalAccountTransactionScreenState();
}

class _PersonalAccountTransactionScreenState extends State<PersonalAccountTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _operationType = 'LoanIn'; // LoanIn / LoanRepayment
  int? _cashBoxId;
  List<Map<String, dynamic>> _cashboxes = [];
  bool _loadingBoxes = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCashboxes();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCashboxes() async {
    final boxes = await CashboxService.getAllCashboxes();
    if (!mounted) return;
    setState(() {
      _cashboxes = boxes;
      _loadingBoxes = false;
      if (_cashBoxId == null && boxes.isNotEmpty) {
        _cashBoxId = (boxes.first['CashBoxID'] as num?)?.toInt();
      }
    });
  }

  String get _uname => widget.username ?? '';

  double get _currentBalance => (widget.account['CurrentBalance'] ?? 0).toDouble();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

    try {
      final result = await PersonalAccountService.createTransaction(
        accountId: (widget.account['PersonalAccountId'] as num).toInt(),
        operationType: _operationType,
        cashBoxId: _cashBoxId ?? 0,
        amount: amount,
        notes: _notesCtrl.text,
        userName: _uname,
      );

      if (!mounted) return;
      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ ${result['message']}' : (result['message']?.toString() ?? 'حدث خطأ'), style: GoogleFonts.cairo(fontSize: 13)),
          backgroundColor: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e', style: GoogleFonts.cairo(fontSize: 13)), backgroundColor: const Color(0xFFC62828), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(dynamic v) {
    return NumberFormat('#,##0').format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIn = _operationType == 'LoanIn';
    final opColor = isIn ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    final accountName = widget.account['AccountName']?.toString() ?? '';
    final afterBalance = _operationType == 'LoanIn'
        ? _currentBalance + (double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0)
        : _currentBalance - (double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('حركة حساب', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 17)),
        backgroundColor: HomeAccent.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'حفظ',
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                : const Icon(Icons.check_rounded),
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            // هيدر الحساب
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isIn
                      ? const [Color(0xFF1E3A8A), Color(0xFF3B82F6)]
                      : const [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: opColor.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(isIn ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(accountName, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(
                              'الرصيد الحالي: ${_fmt(_currentBalance.abs())} ج.م ${_currentBalance > 0 ? '(له)' : _currentBalance < 0 ? '(عليه)' : ''}',
                              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 16),

            // ── نوع العملية ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نوع العملية', style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _opBtn(
                          isDark,
                          selected: isIn,
                          icon: Icons.trending_up_rounded,
                          label: 'قرض دخل',
                          desc: 'فلوس دخلت للحساب',
                          color: const Color(0xFF3B82F6),
                          onTap: () => setState(() => _operationType = 'LoanIn'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _opBtn(
                          isDark,
                          selected: !isIn,
                          icon: Icons.trending_down_rounded,
                          label: 'تسديد قرض',
                          desc: 'تسديد من الحساب',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => setState(() => _operationType = 'LoanRepayment'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── المبلغ والخزينة ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800),
                    validator: (v) {
                      final amt = double.tryParse((v ?? '').replaceAll(',', ''));
                      if (amt == null || amt <= 0) return 'أدخل مبلغاً صحيحاً';
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'المبلغ *',
                      hintText: '0.00',
                      hintStyle: GoogleFonts.cairo(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.attach_money_rounded, size: 20, color: opColor),
                      suffixText: 'ج.م',
                      suffixStyle: GoogleFonts.cairo(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: HomeAccent.gold, width: 1.6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _cashBoxId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'الخزينة *',
                      hintText: _loadingBoxes ? 'جاري تحميل الخزن...' : 'اختر الخزينة',
                      hintStyle: GoogleFonts.cairo(fontSize: 12.5),
                      labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: HomeAccent.gold, width: 1.6)),
                    ),
                    items: _cashboxes.map((b) => DropdownMenuItem<int?>(
                          value: (b['CashBoxID'] as num?)?.toInt(),
                          child: Text(b['CashBoxName']?.toString() ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )).toList(),
                    onChanged: (v) => setState(() => _cashBoxId = v),
                    style: GoogleFonts.cairo(fontSize: 13.5),
                    dropdownColor: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── ملاحظات + معاينة الرصيد ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'اختياري',
                      hintStyle: GoogleFonts.cairo(fontSize: 12.5),
                      labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // معاينة الرصيد بعد الحركة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: opColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: opColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.balance_rounded, size: 18, color: opColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('الرصيد بعد الحركة:', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                        Text(
                          '${_fmt(afterBalance.abs())} ج.م',
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: opColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // زر الحفظ
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeAccent.gold,
                  foregroundColor: const Color(0xFF0D1A2A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1A2A)))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الحركة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _opBtn(
    bool isDark, {
    required bool selected,
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? color : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w800, color: selected ? color : theme.colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(desc, style: GoogleFonts.cairo(fontSize: 10, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
