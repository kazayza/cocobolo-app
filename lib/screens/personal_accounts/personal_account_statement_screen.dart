import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/personal_account_service.dart';
import 'personal_account_form_screen.dart';
import 'personal_account_transaction_screen.dart';

/// مُنسّق أرقام مشترك
final NumberFormat _fmtShared = NumberFormat('#,##0');

/// ─────────────────────────────────────────────────────────────
/// 📄 كشف حساب شخصي — كل الحركات + الرصيد الجاري
/// ─────────────────────────────────────────────────────────────
class PersonalAccountStatementScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  final String? username;

  const PersonalAccountStatementScreen({super.key, required this.account, this.username});

  @override
  State<PersonalAccountStatementScreen> createState() => _PersonalAccountStatementScreenState();
}

class _PersonalAccountStatementScreenState extends State<PersonalAccountStatementScreen> {
  PersonalAccountStatement? _statement;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

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
      final st = await PersonalAccountService.getStatement(
        (widget.account['PersonalAccountId'] as num).toInt(),
        from: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
        to: _to != null ? DateFormat('yyyy-MM-dd').format(_to!) : null,
      );
      if (!mounted) return;
      setState(() {
        _statement = st;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل الكشف';
        _loading = false;
      });
    }
  }

  String get _uname => widget.username ?? '';

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _timeAgo(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final acc = widget.account;
    final balance = (acc['CurrentBalance'] ?? 0).toDouble();
    final balanceColor = balance > 0 ? const Color(0xFFE53935) : (balance < 0 ? const Color(0xFF43A047) : theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Text(acc['AccountName']?.toString() ?? 'كشف حساب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? _buildError(theme)
              : RefreshIndicator(
                  color: HomeAccent.accent,
                  onRefresh: _load,
                  child: _buildBody(theme, isDark, balance, balanceColor),
                ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark, double balance, Color balanceColor) {
    final st = _statement;
    final txs = st?.transactions ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── كارت الرصيد ──────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [HomeAccent.navyDark, HomeAccent.navyLight],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomeAccent.gold.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: HomeAccent.gold.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: HomeAccent.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.account_balance_rounded, color: HomeAccent.gold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الرصيد الحالي', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('${_fmt(balance.abs())} ج.م', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      balance > 0 ? 'له' : (balance < 0 ? 'عليه' : 'مسوى'),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat('رصيد افتتاحي', st?.openingBalance ?? 0),
                  _miniStat('رصيد ختامي', st?.closingBalance ?? 0),
                  _miniStat('عدد الحركات', txs.length),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── أزرار سريعة ──────────────────────────
        Row(
          children: [
            Expanded(
              child: _QuickBtn(
                icon: Icons.add_card_rounded,
                label: 'حركة جديدة',
                color: HomeAccent.indigo,
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonalAccountTransactionScreen(account: widget.account, username: _uname),
                    ),
                  );
                  if (changed == true && mounted) _load();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickBtn(
                icon: Icons.edit_rounded,
                label: 'تعديل الحساب',
                color: HomeAccent.teal,
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonalAccountFormScreen(account: widget.account, username: _uname),
                    ),
                  );
                  if (changed == true && mounted) _load();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── رأس القائمة ──────────────────────────
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: HomeAccent.gold, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('الحركات', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${txs.length} حركة',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (txs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('لا توجد حركات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          )
        else
          ...txs.asMap().entries.map((entry) {
            final tx = entry.value;
            final isIn = (tx['AmountIn'] ?? 0).toDouble() > 0;
            final amount = isIn ? (tx['AmountIn'] ?? 0).toDouble() : (tx['AmountOut'] ?? 0).toDouble();
            final color = isIn ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
            final running = (tx['RunningBalance'] ?? 0).toDouble();
            final runningColor = running > 0 ? const Color(0xFFE53935) : (running < 0 ? const Color(0xFF43A047) : theme.colorScheme.onSurfaceVariant);

            String dateStr = '';
            String timeStr = '';
            try {
              final dt = DateTime.parse(tx['TransactionDate'].toString());
              dateStr = DateFormat('yyyy/MM/dd').format(dt);
              timeStr = DateFormat('HH:mm').format(dt);
            } catch (_) {
              dateStr = tx['TransactionDate']?.toString() ?? '';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
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
                        child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 15, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx['Description']?.toString() ?? '',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                            ),
                            Text(
                              '$dateStr $timeStr',
                              style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isIn ? '+' : '-'}${_fmt(amount)}',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color),
                          ),
                          Text(
                            'رصيد: ${_fmt(running.abs())}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: runningColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if ((tx['CashBoxName'] ?? '').toString().isNotEmpty || (tx['Notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if ((tx['CashBoxName'] ?? '').toString().isNotEmpty)
                          Flexible(
                            child: Text(
                              '${tx['CashBoxName']}',
                              style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if ((tx['Notes'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${tx['Notes']}',
                              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _miniStat(String label, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value is int ? '$value' : _fmt(value),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
