import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../../../screens/quotation_details_screen.dart';
import '../../../screens/quotations_screen.dart';
import '../../../services/app_colors.dart';
import '../../../services/design_tokens.dart';
import '../../../services/permission_service.dart';
import '../../../services/quotation_service.dart';
import '../../../widgets/design_kit.dart';
import 'home_accent.dart';
import 'latest_doc_row.dart';

/// قسم «آخر عروض الأسعار» — مقابل قسم بلازور بالاسم نفسه.
/// البوابة: صلاحية عرض قائمة العروض (frmQuotationsList:View)
/// أو Admin — نفس قاعدة بلازور. ألوان الحالات وتسمياتها منسوخة
/// من شاشة العروض نفسها حتى لا تتضارب التعريفات.
class LatestQuotationsSection extends StatefulWidget {
  const LatestQuotationsSection({super.key});

  @override
  State<LatestQuotationsSection> createState() =>
      _LatestQuotationsSectionState();
}

class _LatestQuotationsSectionState extends State<LatestQuotationsSection> {
  List<dynamic> _quotations = const [];

  bool get _canView {
    final perm = PermissionService();
    return perm.isAdmin ||
        (perm.getPermission('frmQuotationsList')?.canView ?? false);
  }

  @override
  void initState() {
    super.initState();
    if (_canView) _load();
  }

  Future<void> _load() async {
    try {
      final data = await QuotationService().getQuotations(page: 1, limit: 5);
      final list = ((data['rows'] as List?) ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .take(5)
          .toList();
      if (!mounted) return;
      setState(() => _quotations = list);
    } catch (_) {
      // قسم رئيسية اختياري — الفشل يخفيه بصمت
    }
  }

  // نفس تعريفات شاشة العروض (_statusColor/_statusLabel هناك)
  static (Color, String) _statusInfo(Map<dynamic, dynamic> row) {
    final converted = row['InvoiceID'] != null;
    final status = converted ? 'Converted' : '${row['Status'] ?? 'Draft'}';
    return switch (status) {
      'Sent' => (AppColors.info, 'تم الإرسال'),
      'Accepted' => (AppColors.success, 'مقبول'),
      'Rejected' => (AppColors.error, 'مرفوض'),
      'Converted' => (Colors.teal, 'تحوّل لفاتورة'),
      'Expired' => (Colors.deepOrange, 'منتهي'),
      _ => (AppColors.goldDark, 'مسودة'),
    };
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

  int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    if (!_canView || _quotations.isEmpty) return const SizedBox.shrink();

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
                title: 'آخر عروض الأسعار',
                icon: Icons.description_rounded,
                trailing: TextButton(
                  onPressed: () {
                    if (auth.userId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuotationsScreen(
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
              for (var i = 0; i < _quotations.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                Builder(builder: (context) {
                  final row = _quotations[i] as Map<dynamic, dynamic>;
                  final (statusColor, statusLabel) = _statusInfo(row);
                  return LatestDocRow(
                    icon: Icons.description_rounded,
                    accent: HomeAccent.purple,
                    title: (row['PartyName'] ?? '—').toString(),
                    subtitle:
                        '${row['ReferenceNumber'] ?? ''} • ${_date(row['QuotationDate'])}',
                    amount: _fmt(row['GrandTotal']),
                    badge: StatusBadge(
                      label: statusLabel,
                      color: statusColor,
                      small: true,
                    ),
                    onTap: () {
                      if (auth.userId == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuotationDetailsScreen(
                            userId: auth.userId!,
                            username: auth.username ?? '',
                            quotationId: _int(row['QuotationID']),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
