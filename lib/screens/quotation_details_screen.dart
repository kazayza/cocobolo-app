import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import '../services/design_tokens.dart';
import '../services/quotation_service.dart';
import '../widgets/design_kit.dart';
import '../services/theme_service.dart';
import 'invoice/invoice_details_screen.dart';
import 'quotation_form_screen.dart';
import '../core/auth/session_service.dart';

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
      _ => AppColors.neutral,
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
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

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
                  borderRadius: AppRadius.all(AppRadius.sm),
                ),
                child: Icon(
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
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.white),
                    ),
                    Text(
                      'استعراض البنود والإجراءات المالية',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
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
                icon: Icon(Icons.picture_as_pdf_rounded,
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
            ? const AppLoading()
            : _error != null
                ? _errorState()
                : _body(),
      ),
    );
  }

  Widget _errorState() {
    return AppError(message: _error!, onRetry: _load);
  }

  Widget _body() {
    final q = _quotation!;
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, 40),
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
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.all(AppRadius.xxl),
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
                      CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text(
                        'جاري التنفيذ...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
    final client = '${q['PartyName'] ?? 'عميل غير محدد'}';

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppGradients.identityCard,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: AppRadius.all(AppRadius.xxl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: Offset(0, 8),
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
                  borderRadius: AppRadius.all(AppRadius.md),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Icon(Icons.description_rounded,
                    color: AppColors.gold, size: 24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${q['ReferenceNumber'] ?? 'عرض السعر'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      client,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      date == null
                          ? ''
                          : 'تاريخ الإصدار: ${DateFormat('yyyy/MM/dd').format(date.toLocal())}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: _statusLabel(status),
                color: color,
                filled: true,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _heroInfoPill(
                  Icons.workspace_premium_rounded,
                  'الباقة المعتمدة',
                  _tierLabel('${q['PricingType'] ?? 'Premium'}'),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _heroInfoPill(
                  Icons.event_available_rounded,
                  'صالح حتى',
                  valid == null
                      ? 'مفتوح'
                      : DateFormat('yyyy/MM/dd').format(valid.toLocal()),
                ),
              ),
            ],
          ),
          if (!_masked) ...<Widget>[
            SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.gold, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'الإجمالي النهائي للعرض',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  AmountText(
                    value: '${_money(q['GrandTotal'])} ج.م',
                    size: 20,
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
          ],
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
      padding: EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(
          color: highlight
              ? AppColors.gold.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.gold, size: 18),
          SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(color: Colors.white60, fontSize: 9),
          ),
          SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.all(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final phone = '${q['PartyPhone'] ?? ''}'.trim();

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: 'بيانات العميل',
            icon: Icons.person_rounded,
            accent: AppColors.gold,
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: AppRadius.all(AppRadius.lg),
                ),
                child: Text(
                  _initial('${q['PartyName'] ?? ''}'),
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${q['PartyName'] ?? 'عميل غير محدد'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty) ...<Widget>[
                AppIconChip(
                  icon: Icons.call_rounded,
                  color: AppColors.info,
                  tooltip: 'اتصال هاتفي',
                  onTap: () => _call(phone),
                ),
                SizedBox(width: AppSpacing.sm),
                WhatsAppChip(onTap: () => _whatsapp(phone)),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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

  // 3️⃣ قسم الأصناف العصري (Bento Quotation Items)
  Widget _itemsModernSection() {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: _masked ? 'تكلفة الأصناف المدرجة' : 'بنود وأصناف عرض السعر',
            subtitle: 'إجمالي ${_items.length} قطعة مدرجة في هذا العرض',
            icon: Icons.inventory_2_rounded,
            accent: AppColors.goldDark,
          ),
          SizedBox(height: AppSpacing.md),
          if (_items.isEmpty)
            AppEmpty(
              message: 'لا توجد أصناف مسجلة في هذا العرض',
              icon: Icons.inventory_2_outlined,
              onRefresh: _load,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm + 2),
              itemBuilder: (_, int idx) =>
                  _buildBentoItemCard(_items[idx], idx),
            ),
        ],
      ),
    );
  }

  Widget _buildBentoItemCard(Map<String, dynamic> item, int index) {
    final theme = Theme.of(context);
    final cost = _num(item['UnitCost']);
    final quantity = _num(item['Quantity']);
    final price = _num(item['UnitPrice']);
    final imageId = _int(item['MainImageId']);
    final altName = '${item['AlternativeName'] ?? ''}'.trim();
    final desc = '${item['ProductDescription'] ?? ''}'.trim();

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
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
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.all(AppRadius.sm),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: imageId > 0
                        ? Image.network(
                            '$baseUrl/api/product-image-by-id/$imageId',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.gold,
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.gold,
                          ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(AppRadius.sm - 1),
                          bottomLeft: Radius.circular(AppRadius.xs),
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${item['ProductName'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        StatusBadge(
                          label:
                              _tierLabel('${item['PricingTier'] ?? 'Premium'}'),
                          color: AppColors.navy,
                          small: true,
                        ),
                        if (altName.isNotEmpty)
                          StatusBadge(
                            label: 'بديل: $altName',
                            color: AppColors.success,
                            small: true,
                          ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...<Widget>[
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm + 2),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.all(AppRadius.sm),
              border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.layers_outlined,
                        size: 15, color: AppColors.goldDark),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      'الكمية: ${_money(quantity)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!_masked) ...<Widget>[
                      SizedBox(width: AppSpacing.sm + 2),
                      Text(
                        '× ${_money(price)} ج',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_masked)
                  AmountText(
                    value: '${_money(price * quantity)} ج.م',
                    size: 13.5,
                    color: AppColors.goldDark,
                  )
                else
                  AmountText(
                    value: 'التكلفة: ${_money(cost)} ج.م',
                    size: 12,
                    color: AppColors.warning,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4️⃣ كارت الإيصال المالي (Receipt Financial Summary)
  Widget _totalsCard(Map<String, dynamic> q) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: 'الملخص المالي لعرض السعر',
            icon: Icons.calculate_rounded,
            accent: AppColors.gold,
          ),
          SizedBox(height: AppSpacing.md),
          _totalRow('إجمالي قيمة الأصناف', q['TotalAmount']),
          if (_num(q['DiscountAmount']) > 0)
            _totalRow(
              'قيمة الخصم الممنوح',
              -_num(q['DiscountAmount']),
              color: AppColors.error,
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: Divider(),
          ),
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: AppRadius.all(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'الإجمالي النهائي للعرض',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AmountText(
                  value: '${_money(q['GrandTotal'])} ج.م',
                  size: 18,
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
          if (_can('canViewCost')) ...<Widget>[
            SizedBox(height: AppSpacing.sm + 2),
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
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: 'ملاحظات وشروط إضافية',
            icon: Icons.notes_rounded,
            accent: AppColors.goldDark,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            notes,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
    final q = _quotation!;
    final buttons = <Widget>[];

    void addButton(Widget button) {
      if (buttons.isNotEmpty) {
        buttons.add(SizedBox(height: AppSpacing.sm));
      }
      buttons.add(button);
    }

    if (_can('canEdit') && !_converted) {
      addButton(AppButton(
        label: 'تعديل البيانات',
        icon: Icons.edit_rounded,
        color: AppColors.info,
        onTap: () {
          if (!_busy) _edit();
        },
      ));
    }
    if (_can('canEdit') && !_converted) {
      addButton(AppButton(
        label: 'تغيير الحالة',
        icon: Icons.flag_rounded,
        color: AppColors.navy,
        onTap: () {
          if (!_busy) _changeStatus();
        },
      ));
    }
    if (!_masked && !_converted) {
      addButton(AppButton(
        label: 'طلب تسعير مصنع',
        icon: Icons.engineering_rounded,
        color: AppColors.navyLight,
        onTap: () {
          if (!_busy) _requestPricing();
        },
      ));
    }
    if (_can('canEdit') && !_converted && !_masked) {
      addButton(AppButton(
        label: 'طلب موافقة خصم',
        icon: Icons.discount_rounded,
        color: AppColors.warning,
        onTap: () {
          if (!_busy) _requestDiscount();
        },
      ));
    }
    if (_can('canEditCost') && !_converted) {
      addButton(AppButton(
        label: 'تحديث التكاليف',
        icon: Icons.precision_manufacturing_rounded,
        color: AppColors.goldDark,
        onTap: () {
          if (!_busy) _editCosts();
        },
      ));
    }
    if (_converted && _can('canViewSalePrices')) {
      addButton(AppButton(
        label: 'عرض الفاتورة المصدرة',
        icon: Icons.receipt_long_rounded,
        color: AppColors.success,
        onTap: () {
          if (_busy) return;
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => InvoiceDetailsScreen(
                transactionId: _int(q['InvoiceID']),
                username: widget.username,
                invoiceType: 'Sale',
              ),
            ),
          );
        },
      ));
    }
    if (_can('canDelete') && !_converted) {
      addButton(AppButton(
        label: 'حذف العرض',
        icon: Icons.delete_outline_rounded,
        color: AppColors.error,
        onTap: () {
          if (!_busy) _delete();
        },
      ));
    }

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: 'إجراءات التحكم والمتابعة',
            icon: Icons.dashboard_customize_rounded,
            accent: AppColors.goldDark,
          ),
          SizedBox(height: AppSpacing.md),
          ...buttons,
        ],
      ),
    );
  }

  // 6️⃣ الشريط السفلي الثابت للإجراءات السريعة (Sticky Bottom Action Bar)
  Widget _buildStickyBottomBar() {
    final q = _quotation!;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm + 2, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            if (!_masked) ...<Widget>[
              Expanded(
                child: AppButton(
                  label: 'PDF ومشاركة',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.info,
                  onTap: () {
                    if (!_busy) _share();
                  },
                ),
              ),
              SizedBox(width: AppSpacing.sm + 2),
            ],
            if (_can('canConvert') && !_converted)
              Expanded(
                flex: 2,
                child: GoldButton(
                  label: 'تحويل لفاتورة مبيعات',
                  icon: Icons.assignment_turned_in_rounded,
                  onPressed: _busy ? null : _convert,
                ),
              )
            else if (_converted && _can('canViewSalePrices'))
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'فتح الفاتورة المرتبطة',
                  icon: Icons.receipt_long_rounded,
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: strong
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: strong ? 13 : 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          Spacer(),
          AmountText(
            value: '${_money(value)} ج.م',
            color: color ?? theme.colorScheme.onSurface,
            size: strong ? 15 : 13,
            weight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.goldDark),
          SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      // رابط جديد موقّع عند كل مشاركة؛ وعند فشل التوليد يُستخدم المخزّن
      var publicUrl = '${_quotation?['publicUrl'] ?? ''}'.trim();
      try {
        final link = await _service.getShareLink(widget.quotationId);
        final fresh = '${link['publicUrl'] ?? ''}'.trim();
        if (fresh.isNotEmpty) publicUrl = fresh;
      } catch (_) {
        // يُكتفى بالرابط المخزّن الوارد من الخادم
      }
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
         headers: SessionService.instance.authHeaders,);
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