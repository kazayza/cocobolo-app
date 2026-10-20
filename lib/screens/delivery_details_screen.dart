import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../features/home/widgets/home_accent.dart';
import '../services/permission_service.dart';

/// ─────────────────────────────────────────────────────────────
///  تفاصيل فاتورة تسليم كاملة
///  (مطابقة لـ DeliveryDetailDialog في بلازور)
/// ─────────────────────────────────────────────────────────────
class DeliveryDetailsScreen extends StatefulWidget {
  final int transactionId;
  final String username;

  const DeliveryDetailsScreen({
    super.key,
    required this.transactionId,
    required this.username,
  });

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  final PermissionService _perms = PermissionService();

  // ── المبالغ: ادمن + مدير حسابات + محاسب فقط (مش المصنع ولا مدير الإنتاج) ──
  bool get _canSeeAmounts => _perms.canSeeDeliveryAmounts;

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
      final res = await http.get(
        Uri.parse('$baseUrl/api/delivery/${widget.transactionId}'),
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _data = json['data'] is Map
              ? Map<String, dynamic>.from(json['data'])
              : null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'فشل تحميل التفاصيل';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال بالخادم';
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0.00',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل التسليم #${widget.transactionId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
          ? _buildError(theme)
          : _buildBody(theme, isDark),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
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

  Widget _buildBody(ThemeData theme, bool isDark) {
    final d = _data!;
    final products = (d['Products'] as List?) ?? [];
    final status = d['DeliveryStatus'] ?? 'upcoming';
    final isDelivered = status == 'delivered';

    final statusColor = isDelivered
        ? const Color(0xFF43A047)
        : status == 'overdue'
        ? const Color(0xFFE53935)
        : status == 'today'
        ? const Color(0xFFFFA000)
        : status == 'soon'
        ? const Color(0xFFFFB300)
        : HomeAccent.accent;

    final statusText = isDelivered
        ? 'تم التسليم'
        : status == 'overdue'
        ? 'متأخر'
        : status == 'today'
        ? 'اليوم'
        : status == 'soon'
        ? 'خلال أيام'
        : 'قادم';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── بطاقة الحالة ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [HomeAccent.navyDark, HomeAccent.navyLight]
                    : const [HomeAccent.navy, Color(0xFF2C4E77)],
              ),
              borderRadius: BorderRadius.circular(20),
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
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDelivered
                            ? Icons.check_circle_rounded
                            : Icons.local_shipping_rounded,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['ClientName'] ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'فاتورة #${d['TransactionID']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // المبالغ — للمخولين فقط (ادمن/مدير حسابات/محاسب)
                if (_canSeeAmounts)
                  Row(
                    children: [
                      _AmountItem(
                        label: 'الإجمالي',
                        value: _fmt(d['GrandTotal']),
                        color: Colors.white,
                      ),
                      _AmountItem(
                        label: 'المدفوع',
                        value: _fmt(d['PaidAmount']),
                        color: const Color(0xFF66BB6A),
                      ),
                      _AmountItem(
                        label: 'المتبقي',
                        value: _fmt(d['RemainingAmount']),
                        color: const Color(0xFFFF8A65),
                      ),
                    ],
                  )
                else
                  // رسالة واضحة لغير المخولين (المصنع / مدير الإنتاج)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 14, color: Colors.white54),
                        SizedBox(width: 6),
                        Text(
                          'المبالغ المالية غير متاحة لصلاحيتك',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── معلومات الفاتورة ──────────────────────────
          _InfoCard(
            title: 'معلومات الفاتورة',
            icon: Icons.receipt_long_rounded,
            color: HomeAccent.indigo,
            children: [
              _InfoRow(label: 'رقم الفاتورة', value: '#${d['TransactionID']}'),
              _InfoRow(
                label: 'تاريخ الفاتورة',
                value: _date(d['TransactionDate']),
              ),
              _InfoRow(label: 'تاريخ الاستحقاق', value: _date(d['DueDate'])),
              if (d['DeliveredAt'] != null)
                _InfoRow(
                  label: 'تاريخ التسليم',
                  value: _date(d['DeliveredAt']),
                ),
              _InfoRow(label: 'النوع', value: d['TransactionType'] ?? '—'),
            ],
          ),

          const SizedBox(height: 14),

          // ── معلومات العميل ────────────────────────────
          _InfoCard(
            title: 'بيانات العميل',
            icon: Icons.person_rounded,
            color: HomeAccent.teal,
            children: [
              _InfoRow(label: 'الاسم', value: d['ClientName'] ?? '—'),
              _InfoRow(label: 'الهاتف', value: d['Phone'] ?? '—'),
              if ((d['Phone2'] ?? '').toString().isNotEmpty)
                _InfoRow(label: 'هاتف 2', value: d['Phone2'].toString()),
              if ((d['Address'] ?? '').toString().isNotEmpty)
                _InfoRow(label: 'العنوان', value: d['Address'].toString()),
            ],
          ),

          const SizedBox(height: 14),

          // ── المندوب ────────────────────────────────────
          _InfoCard(
            title: 'التسليم',
            icon: Icons.local_shipping_rounded,
            color: HomeAccent.amber,
            children: [
              _InfoRow(
                label: 'مندوب التسليم',
                value: d['DeliveryEmployeeName'] ?? '—',
              ),
              if ((d['DeliveredNotes'] ?? '').toString().isNotEmpty)
                _InfoRow(
                  label: 'ملاحظات التسليم',
                  value: d['DeliveredNotes'].toString(),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── المنتجات ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: HomeAccent.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 18,
                        color: HomeAccent.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'المنتجات (${products.length})',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'لا توجد منتجات',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < products.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    _ProductRow(
                      product: Map<String, dynamic>.from(products[i]),
                      showAmount: _canSeeAmounts,
                    ),
                  ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── أزرار التواصل ─────────────────────────────
          if ((d['Phone'] ?? '').toString().isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(d['Phone'].toString()),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('اتصال'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsapp(d['Phone'].toString()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('واتساب'),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    String formatted = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formatted.startsWith('0')) formatted = '2$formatted';
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool showAmount;

  const _ProductRow({required this.product, this.showAmount = true});

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0.00',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product['ProductName'] ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${product['Quantity'] ?? 0}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // السعر: للمخولين فقط
          if (showAmount) ...[
            const SizedBox(width: 14),
            Text(
              _fmt(product['TotalAmount']),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
