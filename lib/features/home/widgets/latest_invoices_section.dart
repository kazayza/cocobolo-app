import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../../../screens/invoice/invoice_details_screen.dart';
import '../../../screens/invoice/invoices_list_screen.dart';
import '../../../services/design_tokens.dart';
import '../../../services/invoice_service.dart';
import '../../../services/permission_service.dart';
import '../../../widgets/design_kit.dart';
import 'home_accent.dart';
import 'latest_doc_row.dart';

/// قسم «آخر فواتير المبيعات» — مقابل قسم بلازور بالاسم نفسه.
/// البوابة: صلاحية عرض فواتير الأطراف (frm_PartiesInvoices:View)
/// أو Admin — نفس قاعدة بلازور. البيانات من خدمة الفواتير الحالية،
/// والضغط على أي صف يفتح تفاصيل الفاتورة كما في قائمة الفواتير.
class LatestInvoicesSection extends StatefulWidget {
  const LatestInvoicesSection({super.key});

  @override
  State<LatestInvoicesSection> createState() => _LatestInvoicesSectionState();
}

class _LatestInvoicesSectionState extends State<LatestInvoicesSection> {
  List<Map<String, dynamic>> _invoices = const [];

  bool get _canView {
    final perm = PermissionService();
    return perm.isAdmin ||
        (perm.getPermission('frm_PartiesInvoices')?.canView ?? false);
  }

  @override
  void initState() {
    super.initState();
    if (_canView) _load();
  }

  Future<void> _load() async {
    try {
      final data = await InvoiceService.instance.list(
        type: 'Sale',
        filters: const {'page': 1, 'limit': 5},
      );
      final list = ((data['data'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .take(5)
          .toList();
      if (!mounted) return;
      setState(() => _invoices = list);
    } catch (_) {
      // قسم رئيسية اختياري — الفشل يخفيه بصمت
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView || _invoices.isEmpty) return const SizedBox.shrink();

    final auth = AuthProvider();

    return Column(
      children: [
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: 'آخر فواتير المبيعات',
                icon: Icons.receipt_long_rounded,
                trailing: TextButton(
                  onPressed: () {
                    if (auth.userId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SalesInvoicesScreen(
                          userId: auth.userId!,
                          username: auth.username ?? '',
                        ),
                      ),
                    );
                  },
                  child: const Text('عرض الكل'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < _invoices.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                LatestDocRow(
                  icon: Icons.receipt_long_rounded,
                  accent: HomeAccent.indigo,
                  title: (_invoices[i]['PartyName'] ?? '—').toString(),
                  subtitle:
                      '#${_invoices[i]['TransactionID']} • ${_date(_invoices[i]['TransactionDate'])}',
                  amount: _fmt(_invoices[i]['GrandTotal']),
                  badge: InvoiceStatusBadge(
                    status: _invoices[i]['InvoiceStatus']?.toString(),
                    small: true,
                  ),
                  onTap: () {
                    final id = (_invoices[i]['TransactionID'] ?? 0) as int;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoiceDetailsScreen(
                          transactionId: id,
                          username: auth.username ?? '',
                          invoiceType: 'Sale',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
