import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/personal_account_service.dart';

/// ─────────────────────────────────────────────────────────────
/// 👤 إضافة / تعديل حساب شخصي
/// ─────────────────────────────────────────────────────────────
class PersonalAccountFormScreen extends StatefulWidget {
  final Map<String, dynamic>? account;
  final String? username;

  const PersonalAccountFormScreen({super.key, this.account, this.username});

  @override
  State<PersonalAccountFormScreen> createState() => _PersonalAccountFormScreenState();
}

class _PersonalAccountFormScreenState extends State<PersonalAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();

  List<Map<String, dynamic>> _types = [];
  String? _type;
  String _openingType = 'Credit';
  DateTime? _openingDate;
  bool _isActive = true;
  bool _saving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.account != null;
    _loadTypes();
    if (_isEdit) _fillFromAccount();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _nationalIdCtrl.dispose();
    _notesCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final types = await PersonalAccountService.getTypes();
    if (!mounted) return;
    setState(() {
      _types = types;
      if (_type == null && types.isNotEmpty) _type = types.first['value'] as String?;
    });
  }

  void _fillFromAccount() {
    final a = widget.account!;
    _nameCtrl.text = a['AccountName']?.toString() ?? '';
    _phoneCtrl.text = a['Phone']?.toString() ?? '';
    _emailCtrl.text = a['Email']?.toString() ?? '';
    _nationalIdCtrl.text = a['NationalId']?.toString() ?? '';
    _notesCtrl.text = a['Notes']?.toString() ?? '';
    _openingBalanceCtrl.text = _fmtNum((a['OpeningBalance'] ?? 0).toDouble());
    _type = a['AccountType']?.toString();
    _openingType = a['OpeningType']?.toString() ?? 'Credit';
    final od = a['OpeningDate'];
    _openingDate = od != null ? DateTime.tryParse(od.toString()) : null;
    _isActive = (a['IsActive'] ?? true) == true;
  }

  String _fmtNum(double v) {
    if (v == 0) return '';
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String get _uname => widget.username ?? '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final openingBalance = double.tryParse(_openingBalanceCtrl.text.replaceAll(',', '')) ?? 0;

    try {
      final Map<String, dynamic> result;
      if (_isEdit) {
        result = await PersonalAccountService.updateAccount(
          accountId: (widget.account!['PersonalAccountId'] as num).toInt(),
          accountName: name,
          accountType: _type ?? 'Other',
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          nationalId: _nationalIdCtrl.text,
          notes: _notesCtrl.text,
          openingBalance: openingBalance,
          openingDate: _openingDate?.toIso8601String(),
          openingType: _openingType,
          isActive: _isActive,
          userName: _uname,
        );
      } else {
        result = await PersonalAccountService.createAccount(
          accountName: name,
          accountType: _type ?? 'Other',
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          nationalId: _nationalIdCtrl.text,
          notes: _notesCtrl.text,
          openingBalance: openingBalance,
          openingDate: _openingDate?.toIso8601String(),
          openingType: _openingType,
          userName: _uname,
        );
      }

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

  Future<void> _pickOpeningDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'تاريخ الافتتاح',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (picked != null && mounted) setState(() => _openingDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل حساب' : 'حساب جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 17)),
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
            // هيدر
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [HomeAccent.navyDark, HomeAccent.navyLight],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HomeAccent.gold.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: HomeAccent.gold.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? 'تعديل بيانات الحساب' : 'إضافة حساب شخصي', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('مالك، مستثمر، مقرض، موظف (سلفة)...', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 16),

            // ═══ البيانات الأساسية ═══
            _group(
              isDark,
              icon: Icons.person_rounded,
              title: 'بيانات الحساب',
              color: HomeAccent.indigo,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.cairo(fontSize: 14),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الحساب مطلوب' : null,
                  decoration: _input(isDark, icon: Icons.person_rounded, label: 'اسم الحساب *', hint: 'مثال: حسن شاهين'),
                ),
                const SizedBox(height: 12),
                // النوع
                DropdownButtonFormField<String?>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: _input(isDark, icon: Icons.category_rounded, label: 'نوع الحساب', hint: 'اختر النوع'),
                  items: [
                    ..._types.map((t) => DropdownMenuItem<String?>(
                          value: t['value'] as String?,
                          child: Text(t['label'] as String? ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                  style: GoogleFonts.cairo(fontSize: 13.5),
                  dropdownColor: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.cairo(fontSize: 14),
                        decoration: _input(isDark, icon: Icons.phone_rounded, label: 'الهاتف', hint: 'اختياري'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.cairo(fontSize: 14),
                        decoration: _input(isDark, icon: Icons.email_rounded, label: 'البريد', hint: 'اختياري'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalIdCtrl,
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: _input(isDark, icon: Icons.badge_rounded, label: 'الرقم القومي', hint: 'اختياري'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ الرصيد الافتتاحي ═══
            _group(
              isDark,
              icon: Icons.account_balance_wallet_rounded,
              title: 'الرصيد الافتتاحي',
              color: HomeAccent.amber,
              children: [
                TextFormField(
                  controller: _openingBalanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: _input(isDark, icon: Icons.attach_money_rounded, label: 'المبلغ', hint: '0.00'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // نوع الرصيد
                    Expanded(
                      child: _segmentedBtn(
                        isDark,
                        value: _openingType,
                        options: const [
                          (label: 'دائن (له)', value: 'Credit'),
                          (label: 'مدين (عليه)', value: 'Debit'),
                        ],
                        onChanged: (v) => setState(() => _openingType = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // التاريخ
                    Expanded(
                      child: InkWell(
                        onTap: _pickOpeningDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          decoration: BoxDecoration(
                            color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 15, color: _openingDate != null ? HomeAccent.accent : theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _openingDate != null ? DateFormat('yyyy/MM/dd').format(_openingDate!) : 'التاريخ',
                                  style: GoogleFonts.cairo(fontSize: 12.5, color: _openingDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ ملاحظات ═══
            _group(
              isDark,
              icon: Icons.notes_rounded,
              title: 'ملاحظات',
              color: HomeAccent.orange,
              children: [
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: _input(isDark, icon: Icons.notes_rounded, label: 'ملاحظات', hint: 'اختياري'),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: Text('الحساب نشط', style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    activeThumbColor: HomeAccent.green,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ],
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
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _group(
    bool isDark, {
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _input(
    bool isDark, {
    required IconData icon,
    String? label,
    required String hint,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.cairo(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
      labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: HomeAccent.gold, width: 1.6),
      ),
    );
  }

  Widget _segmentedBtn(
    bool isDark, {
    required String value,
    required List<({String label, String value})> options,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: value == opt.value ? HomeAccent.accent.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: value == opt.value ? Border.all(color: HomeAccent.accent.withValues(alpha: 0.4)) : null,
                  ),
                  child: Text(
                    opt.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: value == opt.value ? HomeAccent.accent : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
