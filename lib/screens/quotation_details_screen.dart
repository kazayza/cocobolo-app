import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/quotation_service.dart';
import '../services/theme_service.dart';
import 'invoice/invoice_details_screen.dart';
import 'quotation_form_screen.dart';

class QuotationDetailsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int quotationId;

  const QuotationDetailsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.quotationId,
  });

  @override
  State<QuotationDetailsScreen> createState() => _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends State<QuotationDetailsScreen> {
  final QuotationService _service = QuotationService();
  Map<String, dynamic>? _quotation;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);
  Map<String, dynamic> get _capabilities => _map(_quotation?['capabilities']);
  bool _can(String key) => _capabilities[key] == true;
  List<Map<String, dynamic>> get _items =>
      ((_quotation?['details'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getQuotation(widget.quotationId);
      if (!mounted) return;
      setState(() {
        _quotation = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String get _status => '${_quotation?['Status'] ?? 'Draft'}';
  bool get _converted => _quotation?['InvoiceID'] != null;
  bool get _masked => _quotation?['PricesMasked'] == true;

  Color _statusColor(String status) {
    return switch (status) {
      'Sent' => AppColors.info,
      'Accepted' => AppColors.success,
      'Rejected' => AppColors.error,
      'Converted' => AppColors.successLight,
      'Expired' => AppColors.errorLight,
      _ => AppColors.gold,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'Sent' => 'تم الإرسال',
      'Accepted' => 'مقبول',
      'Rejected' => 'مرفوض',
      'Converted' => 'تحوّل لفاتورة',
      'Expired' => 'منتهي',
      _ => 'مسودة',
    };
  }

  String _tierLabel(String tier) {
    return switch (tier) {
      'CClass' => 'ستاندرد',
      'Elite' => 'إيليت',
      'Mixed' => 'مختلط',
      _ => 'بريميوم',
    };
  }

  String _money(dynamic value) {
    return NumberFormat('#,##0.##', 'en_US').format(_num(value));
  }

  // ===========================================================================
  // 🎨 الواجهة الرسومية العصرية (Bento FinTech Quotation Details UI)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.request_quote_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _quotation == null
                          ? 'تفاصيل عرض السعر'
                          : '${_quotation!['ReferenceNumber'] ?? 'عرض السعر'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    Text(
                      'استعراض البنود والإجراءات المالية',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            if (!_loading && _quotation != null && !_masked)
              IconButton(
                tooltip: 'مشاركة PDF',
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.gold),
              ),
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        bottomNavigationBar:
            (_loading || _error != null || _quotation == null)
                ? null
                : _buildStickyBottomBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? _errorState()
                : _body(),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded,
                size: 54, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: _secondaryTextColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final q = _quotation!;
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
            children: <Widget>[
              _hero(q),
              const SizedBox(height: 14),
              if (_status == 'Rejected' &&
                  '${q['RejectionReason'] ?? ''}'.isNotEmpty)
                _alert(
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                  title: 'تم رفض العرض',
                  text: '${q['RejectionReason']}',
                ),
              if (_converted)
                _alert(
                  color: AppColors.success,
                  icon: Icons.verified_rounded,
                  title: 'عرض محوّل لفاتورة مبيعات',
                  text:
                      'تم إصدار الفاتورة رقم ${q['InvoiceReference'] ?? '#${q['InvoiceID']}'}',
                ),
              _clientCard(q),
              const SizedBox(height: 16),
              _itemsModernSection(),
              if (!_masked) ...<Widget>[
                const SizedBox(height: 16),
                _totalsCard(q),
              ],
              if ('${q['Notes'] ?? ''}'.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _notesCard('${q['Notes']}'),
              ],
              const SizedBox(height: 16),
              _actionsHubCard(),
            ],
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text(
                        'جاري التنفيذ...',
                        style: GoogleFonts.cairo(
                          color: _textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 1️⃣ لوحة العرض العلوية الفخمة (Hero Executive Card)
  Widget _hero(Map<String, dynamic> q) {
    final status = _converted ? 'Converted' : _status;
    final color = _statusColor(status);
    final date = DateTime.tryParse('${q['QuotationDate'] ?? ''}');
    final valid = DateTime.tryParse('${q['ValidUntil'] ?? ''}');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.navy, Color(0xFF1E293B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${q['ReferenceNumber'] ?? 'عرض السعر'}',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      date == null
                          ? ''
                          : 'تاريخ الإصدار: ${DateFormat('yyyy/MM/dd').format(date.toLocal())}',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel(status),
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _heroInfoPill(
                  Icons.workspace_premium_rounded,
                  'الباقة المعتمدة',
                  _tierLabel('${q['PricingType'] ?? 'Premium'}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroInfoPill(
                  Icons.event_available_rounded,
                  'صالح حتى',
                  valid == null
                      ? 'مفتوح'
                      : DateFormat('yyyy/MM/dd').format(valid.toLocal()),
                ),
              ),
              if (!_masked) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: _heroInfoPill(
                    Icons.account_balance_wallet_rounded,
                    'صافي العرض',
                    '${_money(q['GrandTotal'])} ج',
                    highlight: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroInfoPill(
    IconData icon,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.gold.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.gold, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.white60, fontSize: 9),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: highlight ? AppColors.gold : Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alert({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  text,
                  style: GoogleFonts.cairo(
                    color: _textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ بطاقة العميل والربط الذكية (VIP Client Card)
  Widget _clientCard(Map<String, dynamic> q) {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;
    final phone = '${q['PartyPhone'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _initial('${q['PartyName'] ?? ''}'),
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'بيانات العميل',
                      style: GoogleFonts.cairo(
                        color: _secondaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${q['PartyName'] ?? 'عميل غير محدد'}',
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        '📞 $phone',
                        style: GoogleFonts.cairo(
                          color: _secondaryTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty) ...<Widget>[
                _contactBtn(
                  icon: Icons.phone_in_talk_rounded,
                  color: Colors.blue.shade600,
                  tooltip: 'اتصال هاتفي',
                  onTap: () => _call(phone),
                ),
                const SizedBox(width: 8),
                _contactBtn(
                  icon: Icons.chat_rounded,
                  color: Colors.green.shade600,
                  tooltip: 'مراسلة واتساب',
                  onTap: () => _whatsapp(phone),
                ),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _chip(Icons.warehouse_rounded,
                  'المخزن: ${q['WarehouseName'] ?? 'غير محدد'}'),
              _chip(Icons.support_agent_rounded,
                  'المسئول: ${q['EmpName'] ?? 'غير محدد'}'),
              if (_int(q['OpportunityID']) > 0)
                _chip(Icons.track_changes_rounded,
                    'فرصة بيع #${q['OpportunityID']}'),
              if ('${q['CreatedBy'] ?? ''}'.trim().isNotEmpty)
                _chip(Icons.person_outline_rounded,
                    'بواسطة: ${q['CreatedBy']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // 3️⃣ قسم الأصناف العصري (Bento Quotation Items)
  Widget _itemsModernSection() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _masked ? 'تكلفة الأصناف المدرجة' : 'بنود وأصناف عرض السعر',
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'إجمالي ${_items.length} قطعة مدرجة في هذا العرض',
                      style: GoogleFonts.cairo(
                        color: _secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'لا توجد أصناف مسجلة في هذا العرض',
                  style: GoogleFonts.cairo(color: _secondaryTextColor),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, int idx) =>
                  _buildBentoItemCard(_items[idx], idx),
            ),
        ],
      ),
    );
  }

  Widget _buildBentoItemCard(Map<String, dynamic> item, int index) {
    final cost = _num(item['UnitCost']);
    final quantity = _num(item['Quantity']);
    final price = _num(item['UnitPrice']);
    final imageId = _int(item['MainImageId']);
    final altName = '${item['AlternativeName'] ?? ''}'.trim();
    final desc = '${item['ProductDescription'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider(_isDark)),
                    ),
                    child: imageId > 0
                        ? Image.network(
                            '$baseUrl/api/product-image-by-id/$imageId',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.gold,
                            ),
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.gold,
                          ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(11),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.cairo(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${item['ProductName'] ?? ''}',
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _miniBadge(
                          _tierLabel('${item['PricingTier'] ?? 'Premium'}'),
                          AppColors.navy,
                        ),
                        if (altName.isNotEmpty)
                          _miniBadge('بديل: $altName', Colors.teal.shade700),
                      ],
                    ),
                    if (desc.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: _secondaryTextColor,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(_isDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.layers_outlined,
                        size: 15, color: AppColors.goldDark),
                    const SizedBox(width: 4),
                    Text(
                      'الكمية: ${_money(quantity)}',
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!_masked) ...<Widget>[
                      const SizedBox(width: 10),
                      Text(
                        '× ${_money(price)} ج',
                        style: GoogleFonts.cairo(
                          color: _secondaryTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_masked)
                  Text(
                    '${_money(price * quantity)} ج.م',
                    style: GoogleFonts.cairo(
                      color: AppColors.goldDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  Text(
                    'التكلفة: ${_money(cost)} ج.م',
                    style: GoogleFonts.cairo(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: _isDark ? AppColors.gold : color,
        ),
      ),
    );
  }

  // 4️⃣ كارت الإيصال المالي (Receipt Financial Summary)
  Widget _totalsCard(Map<String, dynamic> q) {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.calculate_rounded,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                'الملخص المالي لعرض السعر',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _totalRow('إجمالي قيمة الأصناف', q['TotalAmount']),
          if (_num(q['DiscountAmount']) > 0)
            _totalRow(
              'قيمة الخصم الممنوح',
              -_num(q['DiscountAmount']),
              color: AppColors.error,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'الإجمالي النهائي للعرض',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_money(q['GrandTotal'])} ج.م',
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (_can('canViewCost')) ...<Widget>[
            const SizedBox(height: 10),
            _totalRow(
              'إجمالي التكلفة التقديرية',
              _items.fold<double>(0, (sum, item) {
                return sum + _num(item['UnitCost']) * _num(item['Quantity']);
              }),
              color: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _notesCard(String notes) {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.notes_rounded,
                  color: AppColors.goldDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'ملاحظات وشروط إضافية',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // 5️⃣ مركز الإجراءات والتحكم الإداري (Actions Hub)
  Widget _actionsHubCard() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;
    final q = _quotation!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.dashboard_customize_rounded,
                  color: AppColors.goldDark, size: 19),
              const SizedBox(width: 8),
              Text(
                'إجراءات التحكم والمتابعة',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (_can('canEdit') && !_converted)
                _actionButton(
                  label: 'تعديل البيانات',
                  icon: Icons.edit_rounded,
                  color: AppColors.warning,
                  onTap: _edit,
                ),
              if (_can('canEdit') && !_converted)
                _actionButton(
                  label: 'تغيير الحالة',
                  icon: Icons.flag_rounded,
                  color: AppColors.info,
                  onTap: _changeStatus,
                ),
              if (!_masked && !_converted)
                _actionButton(
                  label: 'طلب تسعير مصنع',
                  icon: Icons.engineering_rounded,
                  color: Colors.indigo,
                  onTap: _requestPricing,
                ),
              if (_can('canEdit') && !_converted && !_masked)
                _actionButton(
                  label: 'طلب موافقة خصم',
                  icon: Icons.discount_rounded,
                  color: Colors.deepOrange,
                  onTap: _requestDiscount,
                ),
              if (_can('canEditCost') && !_converted)
                _actionButton(
                  label: 'تحديث التكاليف',
                  icon: Icons.precision_manufacturing_rounded,
                  color: AppColors.goldDark,
                  onTap: _editCosts,
                ),
              if (_converted && _can('canViewSalePrices'))
                _actionButton(
                  label: 'عرض الفاتورة المصدرة',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => InvoiceDetailsScreen(
                        transactionId: _int(q['InvoiceID']),
                        username: widget.username,
                        invoiceType: 'Sale',
                      ),
                    ),
                  ),
                ),
              if (_can('canDelete') && !_converted)
                _actionButton(
                  label: 'حذف العرض',
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.error,
                  onTap: _delete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 6️⃣ الشريط السفلي الثابت للإجراءات السريعة (Sticky Bottom Action Bar)
  Widget _buildStickyBottomBar() {
    final q = _quotation!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            if (!_masked) ...<Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.gold, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.error, size: 20),
                  label: Text(
                    'PDF ومشاركة',
                    style: GoogleFonts.cairo(
                      color: _textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (_can('canConvert') && !_converted)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _busy ? null : _convert,
                  icon: const Icon(Icons.assignment_turned_in_rounded,
                      color: AppColors.gold, size: 20),
                  label: Text(
                    'تحويل لفاتورة مبيعات',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ),
              )
            else if (_converted && _can('canViewSalePrices'))
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => InvoiceDetailsScreen(
                        transactionId: _int(q['InvoiceID']),
                        username: widget.username,
                        invoiceType: 'Sale',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                  label: Text(
                    'فتح الفاتورة المرتبطة',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    String label,
    dynamic value, {
    Color? color,
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.cairo(
              color: strong ? _textColor : _secondaryTextColor,
              fontSize: strong ? 13 : 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_money(value)} ج.م',
            style: GoogleFonts.cairo(
              color: color ?? _textColor,
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.goldDark),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: _isDark ? Colors.white : color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '20${digits.substring(1)}';
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _edit() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuotationFormScreen(
          userId: widget.userId,
          username: widget.username,
          quotationId: widget.quotationId,
        ),
      ),
    ).then((dynamic changed) {
      if (changed == true) _load();
    });
  }

  Future<void> _changeStatus() async {
    final allowed = <String>['Draft', 'Sent', 'Accepted', 'Rejected', 'Expired']
        .where((String value) => value != _status)
        .toList();
    String? selected;
    String reasonText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('تغيير حالة العرض',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    items: allowed.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(_statusLabel(value)),
                      );
                    }).toList(),
                    onChanged: (String? value) =>
                        setDialogState(() => selected = value),
                    decoration:
                        const InputDecoration(labelText: 'الحالة الجديدة'),
                  ),
                  if (selected == 'Rejected') ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      onChanged: (v) => reasonText = v,
                      decoration: const InputDecoration(labelText: 'سبب الرفض'),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: Text('حفظ', style: GoogleFonts.cairo()),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true || selected == null) return;
    await _run(() async {
      final result = await _service.changeStatus(
        id: widget.quotationId,
        status: selected!,
        reason: reasonText.trim(),
      );
      _message('${result['message'] ?? 'تم تحديث الحالة'}');
      await _load();
    });
  }

  Future<void> _convert() async {
    DateTime invoiceDate = DateUtils.dateOnly(DateTime.now());
    final advances = ((_quotation?['advances'] as List?) ?? const <dynamic>[])
        .map<Map<String, dynamic>>(_map)
        .toList();
    final selectedAdvanceIds = <int>{};
    for (final advance in advances) {
      final type = '${advance['ChargeType'] ?? ''}';
      if (type == 'Advance' || type == 'Inspection') {
        selectedAdvanceIds.add(_int(advance['ChargeID']));
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final selectedTotal = advances
                .where((advance) =>
                    selectedAdvanceIds.contains(_int(advance['ChargeID'])))
                .fold<double>(
                  0,
                  (double sum, Map<String, dynamic> advance) =>
                      sum + _num(advance['ChargeAmount']),
                );
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'تحويل إلى فاتورة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'سيتم إنشاء فاتورة بيع وخصم رصيد منتجات المعرض، وإنشاء فاتورة شراء مرآة للأصناف المخصصة للعميل.',
                        style: GoogleFonts.cairo(fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.calendar_month_rounded),
                        title:
                            Text('تاريخ الفاتورة', style: GoogleFonts.cairo()),
                        subtitle:
                            Text(DateFormat('yyyy/MM/dd').format(invoiceDate)),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: invoiceDate,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (selected != null) {
                            setDialogState(() => invoiceDate = selected);
                          }
                        },
                      ),
                      if (advances.isNotEmpty) ...<Widget>[
                        const Divider(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'الدفعات المقدمة المتاحة',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...advances.map<Widget>((advance) {
                          final chargeId = _int(advance['ChargeID']);
                          final checked = selectedAdvanceIds.contains(chargeId);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${advance['ChargeDescription'] ?? 'دفعة مقدمة'}',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            subtitle: Text(
                              '${advance['ChargeType'] ?? ''}',
                              style: GoogleFonts.cairo(fontSize: 9),
                            ),
                            secondary: Text(
                              '${_money(advance['ChargeAmount'])} ج',
                              style: GoogleFonts.cairo(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedAdvanceIds.add(chargeId);
                                } else {
                                  selectedAdvanceIds.remove(chargeId);
                                }
                              });
                            },
                          );
                        }),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'إجمالي الدفعات المختارة: ${_money(selectedTotal)} ج.م',
                            style: GoogleFonts.cairo(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: Text('تنفيذ التحويل', style: GoogleFonts.cairo()),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await _service.convertToInvoice(
        id: widget.quotationId,
        invoiceDate: invoiceDate,
        warehouseId: _int(_quotation?['WarehouseID']) == 0
            ? null
            : _int(_quotation?['WarehouseID']),
        selectedAdvanceChargeIds: selectedAdvanceIds.toList(),
      );
      _message('${result['message'] ?? 'تم التحويل بنجاح'}');
      await _load();
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حذف عرض السعر',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'هل تريد حذف عرض السعر نهائياً؟',
            style: GoogleFonts.cairo(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('حذف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _service.delete(widget.quotationId);
      if (!mounted) return;
      Navigator.pop(context, true);
    });
  }

  Future<void> _requestPricing() async {
    String noteText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('طلب تسعير من المصنع',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: TextField(
            maxLines: 3,
            onChanged: (v) => noteText = v,
            decoration: const InputDecoration(labelText: 'ملاحظة اختيارية'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('إرسال', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _run(() async {
        final result = await _service.requestPricing(
          id: widget.quotationId,
          note: noteText.trim(),
        );
        _message('${result['message'] ?? 'تم إرسال الطلب'}');
      });
    }
  }

  Future<void> _requestDiscount() async {
    String amountText = '';
    String reasonText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'طلب خصم على عرض السعر',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                onChanged: (v) => amountText = v,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'قيمة الخصم المطلوبة',
                  suffixText: 'ج.م',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => reasonText = v,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'سبب الطلب *'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: () {
                final amount = double.tryParse(amountText.replaceAll(',', ''));
                if (amount == null ||
                    amount <= 0 ||
                    reasonText.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_rounded),
              label: Text('إرسال الطلب', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _run(() async {
        final result = await _service.requestDiscount(
          id: widget.quotationId,
          discountAmount: double.parse(amountText.replaceAll(',', '')),
          reason: reasonText.trim(),
        );
        _message('${result['message'] ?? 'تم إرسال طلب الخصم'}');
      });
    }
  }

  Future<void> _editCosts() async {
    final costValues = <int, String>{};
    for (final item in _items) {
      costValues[_int(item['QuotationDetailID'])] = '${_num(item['UnitCost'])}';
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'تحديث تكلفة الأصناف',
                  style: GoogleFonts.cairo(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, int index) {
                      final item = _items[index];
                      final detailId = _int(item['QuotationDetailID']);
                      return TextFormField(
                        initialValue: costValues[detailId],
                        onChanged: (v) => costValues[detailId] = v,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: GoogleFonts.cairo(color: _textColor),
                        decoration: InputDecoration(
                          labelText:
                              '${item['ProductName']} — ${_tierLabel('${item['PricingTier']}')}',
                          suffixText: 'ج.م',
                          filled: true,
                          fillColor: AppColors.inputFill(_isDark),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.save_rounded),
                    label: Text('حفظ التكاليف', style: GoogleFonts.cairo()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) {
      final updates = <Map<String, dynamic>>[];
      costValues.forEach((int detailId, String textValue) {
        final value = double.tryParse(textValue.replaceAll(',', ''));
        if (value != null && value > 0) {
          updates.add(<String, dynamic>{
            'quotationDetailId': detailId,
            'unitCost': value,
          });
        }
      });
      await _run(() async {
        final result =
            await _service.saveCosts(id: widget.quotationId, updates: updates);
        _message('${result['message'] ?? 'تم حفظ التكاليف'}');
        await _load();
      });
    }
  }

  Future<void> _share() async {
    await _run(() async {
      final publicUrl = '${_quotation?['publicUrl'] ?? ''}'.trim();
      final file = await _buildPdf();
      final customer = '${_quotation?['PartyName'] ?? 'العميل'}'.trim();
      final reference =
          '${_quotation?['ReferenceNumber'] ?? 'QT-${widget.quotationId}'}';
      final title = 'عرض سعر - $customer - $reference';
      final text = publicUrl.isEmpty ? title : '$title\n$publicUrl';
      await SharePlus.instance.share(
        ShareParams(
          subject: title,
          text: text,
          files: <XFile>[
            XFile(file.path, mimeType: 'application/pdf'),
          ],
          fileNameOverrides: <String>[file.uri.pathSegments.last],
        ),
      );
    });
  }

  // ===========================================================================
  // 🖨️ قسم طباعة الـ PDF (محفوظ كما هو 100% مع إصلاح الكلمتين فقط)
  // ===========================================================================

  Future<File> _buildPdf() async {
    final quote = _quotation!;
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final backgroundData =
        await rootBundle.load('assets/images/design-background.png');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final background = pw.MemoryImage(backgroundData.buffer.asUint8List());
    final images = await _loadPdfProductImages();
    final document = pw.Document(
      title: 'عرض سعر ${quote['ReferenceNumber'] ?? widget.quotationId}',
      author: 'COCOBOLO',
      subject: 'عرض سعر للعميل ${quote['PartyName'] ?? ''}',
    );

    final itemPages = <List<Map<String, dynamic>>>[];
    final allItems = _items;
    if (allItems.isEmpty) {
      itemPages.add(<Map<String, dynamic>>[]);
    } else {
      itemPages.add(allItems.take(5).toList());
      var remaining = allItems.skip(5).toList();
      while (remaining.isNotEmpty) {
        itemPages.add(remaining.take(7).toList());
        remaining = remaining.skip(7).toList();
      }
    }

    var rowStart = 0;
    for (var pageIndex = 0; pageIndex < itemPages.length; pageIndex++) {
      final pageItems = itemPages[pageIndex];
      document.addPage(
        _quotationProductsPdfPage(
          quote: quote,
          items: pageItems,
          pageIndex: pageIndex,
          rowStart: rowStart,
          background: background,
          images: images,
          regular: regular,
          bold: bold,
        ),
      );
      rowStart += pageItems.length;
    }

    document.addPage(
      _quotationSummaryPdfPage(
        quote: quote,
        background: background,
        regular: regular,
        bold: bold,
      ),
    );
    document.addPage(
      _quotationTermsPdfPage(
        quote: quote,
        background: background,
        regular: regular,
        bold: bold,
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final customer = _safeFilePart('${quote['PartyName'] ?? 'العميل'}');
    final reference = _safeFilePart(
      '${quote['ReferenceNumber'] ?? 'QT-${widget.quotationId}'}',
    );
    final file = File(
      '${directory.path}/عرض_سعر_${customer}_$reference.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  Future<Map<int, pw.MemoryImage>> _loadPdfProductImages() async {
    final result = <int, pw.MemoryImage>{};
    for (final item in _items) {
      final productId = _int(item['ProductID']);
      final imageId = _int(item['MainImageId']);
      if (productId <= 0 || imageId <= 0 || result.containsKey(productId)) {
        continue;
      }
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/product-image-by-id/$imageId'),
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          result[productId] = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }
    return result;
  }

  pw.Page _quotationProductsPdfPage({
    required Map<String, dynamic> quote,
    required List<Map<String, dynamic>> items,
    required int pageIndex,
    required int rowStart,
    required pw.MemoryImage background,
    required Map<int, pw.MemoryImage> images,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => pw.Stack(
        children: <pw.Widget>[
          pw.Positioned.fill(
            child: pw.Image(background, fit: pw.BoxFit.cover),
          ),
          if (pageIndex == 0)
            pw.Positioned(
              top: 14 * PdfPageFormat.mm,
              left: 14 * PdfPageFormat.mm,
              child: pw.SizedBox(
                width: 52 * PdfPageFormat.mm,
                child: _quotationTopMeta(quote, regular, bold),
              ),
            ),
          pw.Positioned(
            top: 42 * PdfPageFormat.mm,
            bottom: 38 * PdfPageFormat.mm,
            left: 12 * PdfPageFormat.mm,
            right: 12 * PdfPageFormat.mm,
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  if (pageIndex == 0) ...<pw.Widget>[
                    _quotationPartyGrid(quote, regular, bold),
                    pw.SizedBox(height: 12),
                  ],
                  _quotationItemsTable(
                    items: items,
                    rowStart: rowStart,
                    images: images,
                    regular: regular,
                    bold: bold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تم إصلاح اتجاه النص العربي هنا عبر إضافة pw.Directionality(textDirection: pw.TextDirection.rtl)
  // مع إصلاح رسم حرف الضاد في خط Cairo
  pw.Widget _quotationTopMeta(
    Map<String, dynamic> quote,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        children: <pw.Widget>[
          pw.Text(
            'عـرض سعر',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              color: const PdfColor.fromInt(0xFFB8860B),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            '${quote['ReferenceNumber'] ?? ''}',
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: bold,
              fontSize: 10,
              color: PdfColors.grey800,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _pdfDate(quote['QuotationDate']),
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: regular,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _quotationPartyGrid(
    Map<String, dynamic> quote,
    pw.Font regular,
    pw.Font bold,
  ) {
    final validUntil = _pdfDate(quote['ValidUntil']);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Expanded(
          child: _quotationInfoBox(
            title: 'العميل',
            lines: <String>[
              'الاسم: ${quote['PartyName'] ?? ''}',
              if ('${quote['PartyPhone'] ?? ''}'.trim().isNotEmpty)
                'الهاتف: ${quote['PartyPhone']}',
              if ('${quote['PartyEmail'] ?? ''}'.trim().isNotEmpty)
                'البريد: ${quote['PartyEmail']}',
              if ('${quote['PartyAddress'] ?? ''}'.trim().isNotEmpty)
                'العنوان: ${quote['PartyAddress']}',
            ],
            regular: regular,
            bold: bold,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _quotationInfoBox(
            title: 'تفاصيل العرض',
            lines: <String>[
              'عـرض سعر - ${quote['ReferenceNumber'] ?? ''}',
              'تاريخ العرض: ${_pdfDate(quote['QuotationDate'])}',
              if (validUntil != '-') 'صالح حتى: $validUntil',
              if ('${quote['EmpName'] ?? ''}'.trim().isNotEmpty)
                'المهندس المسئول: ${quote['EmpName']}',
              'الباقة: ${_tierLabel('${quote['PricingType'] ?? 'Premium'}')}',
              'الحالة: ${_statusLabel('${quote['Status'] ?? 'Draft'}')}',
            ],
            regular: regular,
            bold: bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _quotationInfoBox({
    required String title,
    required List<String> lines,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAF6E8),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0x55D4AF37),
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 10,
              color: const PdfColor.fromInt(0xFF1A2842),
            ),
          ),
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            height: 0.7,
            color: const PdfColor.fromInt(0x55D4AF37),
          ),
          ...lines.map(
            (String line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                line,
                style: pw.TextStyle(font: regular, fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _quotationItemsTable({
    required List<Map<String, dynamic>> items,
    required int rowStart,
    required Map<int, pw.MemoryImage> images,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    const navy = PdfColor.fromInt(0xFF1A2842);
    const border = PdfColor.fromInt(0xFFDDDDDD);
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: navy),
        children: <pw.Widget>[
          _quotationTableHeader('الإجمالي', bold),
          _quotationTableHeader('السعر', bold),
          _quotationTableHeader('الكمية', bold),
          _quotationTableHeader('الوصف', bold),
          _quotationTableHeader('صورة القطعة', bold),
          _quotationTableHeader('#', bold),
        ],
      ),
    ];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final productId = _int(item['ProductID']);
      final quantity = _num(item['Quantity']);
      final unitPrice = _num(item['UnitPrice']);
      final image = images[productId];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isOdd
                ? const PdfColor.fromInt(0xFFFAFAFA)
                : PdfColors.white,
          ),
          children: <pw.Widget>[
            _quotationTableCell(
              '${_money(quantity * unitPrice)} ج',
              regular,
              bold: true,
              align: pw.Alignment.center,
            ),
            _quotationTableCell(
              '${_money(unitPrice)} ج',
              regular,
              align: pw.Alignment.center,
            ),
            _quotationTableCell(
              _money(quantity),
              regular,
              align: pw.Alignment.center,
            ),
            pw.Container(
              height: 70,
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '${item['ProductName'] ?? ''}',
                    style: pw.TextStyle(font: bold, fontSize: 8.5),
                    maxLines: 2,
                  ),
                  if ('${item['ProductDescription'] ?? ''}'.trim().isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(
                        '${item['ProductDescription']}',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 6.8,
                          color: PdfColors.grey700,
                        ),
                        maxLines: 3,
                      ),
                    ),
                ],
              ),
            ),
            pw.Container(
              height: 70,
              padding: const pw.EdgeInsets.all(4),
              alignment: pw.Alignment.center,
              child: image == null
                  ? pw.Container(
                      width: 58,
                      height: 58,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'لا توجد صورة',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 6.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    )
                  : pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(
                        image,
                        width: 58,
                        height: 58,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
            ),
            _quotationTableCell(
              '${rowStart + index + 1}',
              regular,
              align: pw.Alignment.center,
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      rows.add(
        pw.TableRow(
          children: <pw.Widget>[
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'لا توجد أصناف',
                style: pw.TextStyle(font: regular),
              ),
            ),
            ...List<pw.Widget>.generate(
              5,
              (_) => pw.SizedBox(),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.7),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(70),
        1: pw.FixedColumnWidth(64),
        2: pw.FixedColumnWidth(50),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FixedColumnWidth(78),
        5: pw.FixedColumnWidth(30),
      },
      children: rows,
    );
  }

  pw.Widget _quotationTableHeader(String text, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 8,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _quotationTableCell(
    String text,
    pw.Font regular, {
    pw.Font? boldFont,
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerRight,
  }) {
    return pw.Container(
      height: 70,
      padding: const pw.EdgeInsets.all(5),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? (boldFont ?? regular) : regular,
          fontSize: 7.5,
        ),
      ),
    );
  }

  pw.Page _quotationSummaryPdfPage({
    required Map<String, dynamic> quote,
    required pw.MemoryImage background,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => pw.Stack(
        children: <pw.Widget>[
          pw.Positioned.fill(
            child: pw.Image(background, fit: pw.BoxFit.cover),
          ),
          pw.Positioned(
            top: 42 * PdfPageFormat.mm,
            bottom: 38 * PdfPageFormat.mm,
            left: 12 * PdfPageFormat.mm,
            right: 12 * PdfPageFormat.mm,
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: <pw.Widget>[
                  pw.Text(
                    'الملخص المالي',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 22,
                      color: const PdfColor.fromInt(0xFF1A2842),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '${quote['ReferenceNumber'] ?? ''}',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 13,
                      color: const PdfColor.fromInt(0xFFB8860B),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: 120,
                    height: 2,
                    color: const PdfColor.fromInt(0xFFD4AF37),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Container(
                    width: 410,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0x44D4AF37),
                      ),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: <pw.Widget>[
                        _pdfTotalRow(
                          'إجمالي الأصناف',
                          quote['TotalAmount'],
                          regular,
                          bold,
                        ),
                        if (_num(quote['DiscountAmount']) > 0)
                          _pdfTotalRow(
                            'الخصم',
                            -_num(quote['DiscountAmount']),
                            regular,
                            bold,
                            valueColor: PdfColors.red700,
                          ),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFAF6E8),
                            border: pw.Border(
                              top: pw.BorderSide(
                                color: PdfColor.fromInt(0xFFD4AF37),
                                width: 1.5,
                              ),
                              bottom: pw.BorderSide(
                                color: PdfColor.fromInt(0xFFD4AF37),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: _pdfTotalRow(
                            'الإجمالي النهائي',
                            quote['GrandTotal'],
                            regular,
                            bold,
                            strong: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ('${quote['Notes'] ?? ''}'
                      .trim()
                      .isNotEmpty) ...<pw.Widget>[
                    pw.SizedBox(height: 18),
                    pw.Container(
                      width: 410,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFFAFAFA),
                        border: pw.Border(
                          right: pw.BorderSide(
                            color: PdfColor.fromInt(0xFFD4AF37),
                            width: 3,
                          ),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            'ملاحظات:',
                            style: pw.TextStyle(font: bold, fontSize: 10),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '${quote['Notes']}',
                            style: pw.TextStyle(font: regular, fontSize: 8.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 28),
                  pw.SizedBox(
                    width: 410,
                    child: pw.Row(
                      children: <pw.Widget>[
                        pw.Expanded(
                          child: _signatureBox(
                            'توقيع الموظف',
                            '${quote['EmpName'] ?? ''}',
                            regular,
                            bold,
                          ),
                        ),
                        pw.SizedBox(width: 50),
                        pw.Expanded(
                          child: _signatureBox(
                            'توقيع العميل',
                            '${quote['PartyName'] ?? ''}',
                            regular,
                            bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(
    String label,
    String name,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Container(height: 1, color: PdfColors.grey800),
        pw.SizedBox(height: 6),
        pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 9)),
        pw.SizedBox(height: 3),
        pw.Text(
          name,
          style: pw.TextStyle(
            font: regular,
            fontSize: 7.5,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Page _quotationTermsPdfPage({
    required Map<String, dynamic> quote,
    required pw.MemoryImage background,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final validUntil = _pdfDate(quote['ValidUntil']);
    final validityText =
        validUntil == '-' ? '15 يوم من تاريخ الإصدار' : validUntil;
    final rightSections = <({String title, List<String> lines})>[
      (
        title: 'أولًا: صلاحية العرض واعتماده',
        lines: <String>[
          'صلاحية هذا العرض حتى $validityText وبعدها يحق للشركة تعديل الأسعار.',
          'بمجرد قبول العميل لعرض السعر يتم تحويله لفاتورة وتطبق عليه شروط التعاقد الكاملة.',
        ],
      ),
      (
        title: 'ثانيًا: مدة التنفيذ واعتماد أمر التشغيل (Job Order)',
        lines: <String>[
          'مدة التنفيذ تبدأ من تاريخ اعتماد أمر التشغيل التنفيذى، وليس من تاريخ توقيع العقد.',
          'لا يبدأ احتساب مدة التنفيذ إلا بعد توقيع العميل على أمر التشغيل وسداد 70% من إجمالي قيمة التعاقد، ويُعد بدء التنفيذ موافقة نهائية على التعاقد، ولا يجوز للعميل إلغاء التعاقد أو طلب استرداد المبالغ المسددة بعد بدء التنفيذ.',
          'يحق للعميل طلب التعديلات على أمر التشغيل خلال 48 ساعة من تاريخ إرساله إليه عبر الواتساب أو البريد الإلكتروني الرسمي.',
          'بانقضاء الـ48 ساعة دون ملاحظات، يُعد أمر التشغيل معتمدًا ونهائيًا ومجمّدًا (Final & Frozen)، ولا تُقبل أي تعديلات لاحقة إلا بموافقة الشركة، ويترتب على هذه التعديلات تكلفة إضافية وتأخير في مدة التنفيذ.',
        ],
      ),
      (
        title: 'ثالثًا: الإلغاء والتعديل',
        lines: <String>[
          'يحق للعميل إلغاء أو تعديل التعاقد فقط خلال يومان من تاريخ التعاقد بدون أي خصومات.',
          'في حالة رغبة العميل في إلغاء التعاقد بعد مرور 3 أيام يتم خصم 50% من قيمة البند أو إضافتها في حال التعديل.',
        ],
      ),
      (
        title: 'رابعًا: الضمان والصيانة',
        lines: <String>[
          'فترة الضمان تصل إلى 5 سنوات من تاريخ الاستلام ضد عيوب الصناعة وصيانة مدى الحياة.',
          'يسقط الضمان بمجرد نقل المنتج من مكان إلى آخر أو إعادة الفك أو التركيب بمعرفة العميل.',
          'في حالة وجود عيب صناعة بالمنتج تقوم الشركة بإصلاح أو استبدال الجزء محل العيب فقط وليس كامل المنتج وذلك بعد المعاينة الفنية من قبل الشركة.',
          'بمجرد استلام العميل للمنتج لا يجوز استبداله أو استرجاعه وإنما تسري عليه شروط وأحكام الضمان وخدمة ما بعد البيع.',
        ],
      ),
    ];
    final leftSections = <({String title, List<String> lines})>[
      (
        title: 'خامسًا: الاستلام والتسليم',
        lines: <String>[
          'يوقع العميل أو من ينوب عنه إذن استلام للمنتج بمجرد استلامه ومعاينته المعاينة التامة.',
          'لا يتم الاستلام إلا بعد سداد كامل القيمة وفي حالة تأخير العميل في الاستلام يجب سداد المبلغ كاملًا بمجرد الانتهاء من التشطيب.',
          'لتحديد موعد استلام أو خدمات ما بعد البيع يتم الاتصال على (01012455122) وذلك قبل 15 يومًا على الأقل.',
          'يجوز للعميل تغيير موعد الاستلام المتفق عليه مسبقًا وذلك قبل تاريخ الاستلام بـ7 أيام على الأقل.',
        ],
      ),
      (
        title: 'سادسًا: الأسعار والتصنيع',
        lines: <String>[
          'الأسعار غير شاملة ضريبة القيمة المضافة، وجميع المبالغ الواردة بهذا العرض بعملة الجنيه المصري.',
          'الأسعار غير شاملة تكاليف أي معدات وأدوات مناولة خاصة مثل (أوناش أو كلارك أو هاند ليفت... إلخ).',
          'ملاءمة المنتج لموقع العميل من حيث المقاسات والذوق العام مسئولية العميل وحده دون غيره حيث إن المنتجات تم تصنيعها خصيصًا بناءً على طلبه وبالمواصفات المحددة من قبله.',
          'في حالة معاينة الموقع ورفع المقاسات من قبل الشركة تكون المقاسات مسئولية الشركة.',
        ],
      ),
      (
        title: 'سابعًا: شروط الدفعات (عند الموافقة)',
        lines: <String>[
          '70% مقدم تعاقد.',
          '20% بعد صور أعمال النجارة.',
          '10% قبل التسليم.',
        ],
      ),
    ];

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => pw.Stack(
        children: <pw.Widget>[
          pw.Positioned.fill(
            child: pw.Image(background, fit: pw.BoxFit.cover),
          ),
          pw.Positioned(
            top: 14 * PdfPageFormat.mm,
            left: 14 * PdfPageFormat.mm,
            child: pw.SizedBox(
              width: 52 * PdfPageFormat.mm,
              child: _quotationTopMeta(quote, regular, bold),
            ),
          ),
          pw.Positioned(
            top: 39 * PdfPageFormat.mm,
            bottom: 34 * PdfPageFormat.mm,
            left: 11 * PdfPageFormat.mm,
            right: 11 * PdfPageFormat.mm,
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: <pw.Widget>[
                  // ✅ تم إصلاح ظهور حرف الضاد في كلمة (عـرض)
                  pw.Text(
                    'شروط وأحكام عـرض السعر',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 17,
                      color: const PdfColor.fromInt(0xFFB8860B),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: 180,
                    height: 1.5,
                    color: const PdfColor.fromInt(0xFFD4AF37),
                  ),
                  pw.SizedBox(height: 9),
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: rightSections
                                .map(
                                  (section) => _termsSection(
                                    section.title,
                                    section.lines,
                                    regular,
                                    bold,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: leftSections
                                .map(
                                  (section) => _termsSection(
                                    section.title,
                                    section.lines,
                                    regular,
                                    bold,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Row(
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: _signatureBox(
                          'توقيع العميل',
                          '',
                          regular,
                          bold,
                        ),
                      ),
                      pw.SizedBox(width: 50),
                      pw.Expanded(
                        child: _signatureBox(
                          'توقيع الشركة',
                          '',
                          regular,
                          bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _termsSection(
    String title,
    List<String> lines,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFAF6E8),
              border: pw.Border(
                right: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFD4AF37),
                  width: 3,
                ),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: bold,
                fontSize: 7.4,
                color: const PdfColor.fromInt(0xFFB8860B),
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          ...lines.map(
            (String line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '•',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 7.2,
                      color: const PdfColor.fromInt(0xFF1A2842),
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      line,
                      textAlign: pw.TextAlign.justify,
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 6.65,
                        lineSpacing: 1.5,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeFilePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'بدون_اسم' : cleaned;
  }

  String _pdfDate(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '-' : DateFormat('yyyy/MM/dd').format(date.toLocal());
  }

  pw.Widget _pdfTotalRow(
    String label,
    dynamic value,
    pw.Font regular,
    pw.Font bold, {
    bool strong = false,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label,
              style: pw.TextStyle(
                  font: strong ? bold : regular, fontSize: strong ? 11 : 9)),
          pw.Text(
            '${_money(value)} ج.م',
            style: pw.TextStyle(
              font: strong ? bold : regular,
              fontSize: strong ? 11 : 9,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? 'ع' : clean.substring(0, 1);
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}