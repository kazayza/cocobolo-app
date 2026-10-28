import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../constants.dart';
import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/quotation_service.dart';
import '../services/theme_service.dart';

class QuotationFormScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? quotationId;

  const QuotationFormScreen({
    super.key,
    required this.userId,
    required this.username,
    this.quotationId,
  });

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  final QuotationService _service = QuotationService();
  final TextEditingController _partySearchController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final List<_QuotationItem> _items = <_QuotationItem>[];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _referenceNumber;
  int? _partyId;
  String? _partyName;
  String? _partyPhone;
  int? _warehouseId;
  int? _opportunityId;
  DateTime _quotationDate = DateUtils.dateOnly(DateTime.now());
  DateTime? _validUntil = DateUtils.dateOnly(DateTime.now()).add(
    const Duration(days: 15),
  );
  String _status = 'Draft';
  List<Map<String, dynamic>> _warehouses = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _opportunities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];

  bool get _isEdit => widget.quotationId != null && widget.quotationId! > 0;
  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);

  double get _total => _items.fold<double>(
        0,
        (double sum, _QuotationItem item) => sum + item.total,
      );
  double get _discount {
    final value =
        double.tryParse(_discountController.text.replaceAll(',', '')) ?? 0;
    return value.clamp(0, _total).toDouble();
  }

  double get _grand =>
      (_total - _discount).clamp(0, double.infinity).toDouble();

  static String _safeInitial(String? text, [String fallback = 'ع']) {
    final clean = (text ?? '').trim();
    if (clean.isEmpty) return fallback;
    return clean.substring(0, 1);
  }

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_refreshTotals);
    _bootstrap();
  }

  @override
  void dispose() {
    _partySearchController.dispose();
    _productSearchController.dispose();
    _discountController
      ..removeListener(_refreshTotals)
      ..dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _refreshTotals() {
    if (mounted) setState(() {});
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future<dynamic>>[
        _service.getLookups(),
        if (_isEdit) _service.getQuotation(widget.quotationId!),
      ];
      final results = await Future.wait<dynamic>(futures);
      final lookups = _map(results[0]);
      _warehouses = ((lookups['warehouses'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      if (_isEdit) _fillQuotation(_map(results[1]));
      if (_partyId != null) await _loadPartyData();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _fillQuotation(Map<String, dynamic> data) {
    _referenceNumber = '${data['ReferenceNumber'] ?? ''}';
    _partyId = _int(data['PartyID']);
    _partyName = '${data['PartyName'] ?? ''}';
    _partyPhone = '${data['PartyPhone'] ?? ''}';
    _warehouseId =
        _int(data['WarehouseID']) == 0 ? null : _int(data['WarehouseID']);
    _opportunityId =
        _int(data['OpportunityID']) == 0 ? null : _int(data['OpportunityID']);
    _quotationDate = DateUtils.dateOnly(
      DateTime.tryParse('${data['QuotationDate'] ?? ''}') ?? DateTime.now(),
    );
    _validUntil = data['ValidUntil'] == null
        ? null
        : DateUtils.dateOnly(
            DateTime.tryParse('${data['ValidUntil']}') ?? DateTime.now(),
          );
    _status = '${data['Status'] ?? 'Draft'}';
    _discountController.text = '${_num(data['DiscountAmount'])}';
    _notesController.text = '${data['Notes'] ?? ''}';
    for (final raw in (data['details'] as List?) ?? const <dynamic>[]) {
      final detail = _map(raw);
      _items.add(
        _QuotationItem(
          quotationDetailId: _int(detail['QuotationDetailID']),
          productId: _int(detail['ProductID']),
          productName: '${detail['ProductName'] ?? ''}',
          productDescription: '${detail['ProductDescription'] ?? ''}',
          pricingTier: '${detail['PricingTier'] ?? 'Premium'}',
          selectedAlternativeId: _int(detail['SelectedAlternativeID']) == 0
              ? null
              : _int(detail['SelectedAlternativeID']),
          selectedAlternativeName: '${detail['AlternativeName'] ?? ''}',
          quantity: _num(detail['Quantity']),
          unitPrice: _num(detail['UnitPrice']),
          notes: _stripTier('${detail['Notes'] ?? ''}'),
          onChanged: _refreshTotals,
        ),
      );
    }
  }

  String _stripTier(String notes) {
    if (!notes.startsWith('[') || !notes.contains(']')) return notes;
    return notes.substring(notes.indexOf(']') + 1).trim();
  }

  Future<void> _loadPartyData() async {
    if (_partyId == null) return;
    try {
      final lookups = await _service.getLookups(partyId: _partyId);
      if (!mounted) return;
      final opportunities =
          ((lookups['opportunities'] as List?) ?? const <dynamic>[])
              .map<Map<String, dynamic>>(_map)
              .toList();
      if (!mounted) return;
      setState(() {
        _opportunities = opportunities;
      });
      await _loadProducts();
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _loadProducts({String search = ''}) async {
    if (_partyId == null) return;
    final rows = await _service.getProducts(
      partyId: _partyId!,
      warehouseId: _warehouseId,
      search: search,
    );
    if (!mounted) return;
    setState(() {
      _products = rows.map<Map<String, dynamic>>(_map).toList();
    });
  }

  // ===========================================================================
  // 🚀 النوافذ الذكية المنبثقة (محمية 100% ضد الشاشة الحمراء)
  // ===========================================================================

  Future<void> _selectParty() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _QuotationPartySearchSheet(
        isDark: _isDark,
        onSearch: (String q) async {
          final data = await _service.getLookups(search: q.trim());
          return ((data['parties'] as List?) ?? const <dynamic>[])
              .map<Map<String, dynamic>>(_map)
              .toList();
        },
      ),
    );

    if (chosen == null || !mounted) return;

    final staleItems = List<_QuotationItem>.from(_items);
    setState(() {
      _partyId = _int(chosen['PartyID']);
      _partyName = '${chosen['PartyName'] ?? ''}';
      _partyPhone = '${chosen['Phone'] ?? ''}';
      _opportunityId = null;
      _items.clear();
      _opportunities = <Map<String, dynamic>>[];
      _products = <Map<String, dynamic>>[];
    });
    for (final item in staleItems) {
      item.dispose();
    }
    await _loadPartyData();
  }

  Future<void> _pickProduct() async {
    if (_partyId == null) {
      _message('اختر العميل أولاً لعرض المنتجات المتاحة', error: true);
      return;
    }
    await _loadProducts();
    if (!mounted) return;

    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _QuotationProductPickerSheet(
        isDark: _isDark,
        initialProducts: _products,
        onSearch: (String q) async {
          final rows = await _service.getProducts(
            partyId: _partyId!,
            warehouseId: _warehouseId,
            search: q.trim(),
          );
          return rows.map<Map<String, dynamic>>(_map).toList();
        },
      ),
    );

    if (product != null && mounted) {
      await _configureProduct(product);
    }
  }

  Future<void> _configureProduct(
    Map<String, dynamic> product, {
    _QuotationItem? existing,
  }) async {
    final rawAlternatives =
        await _service.getAlternatives(_int(product['ProductID']));
    if (!mounted) return;

    final alternatives =
        rawAlternatives.map<Map<String, dynamic>>(_map).toList();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _ConfigureProductSheet(
        isDark: _isDark,
        product: product,
        alternatives: alternatives,
        existing: existing,
        onValidationError: (String msg) => _message(msg, error: true),
      ),
    );

    if (result != null && mounted) {
      final tier = result['tier'] as String;
      final alternativeId = result['alternativeId'] as int?;
      final selectedAlternative =
          result['selectedAlternative'] as Map<String, dynamic>?;
      final quantity = result['quantity'] as double;
      final price = result['price'] as double;
      final notes = result['notes'] as String;

      if (existing == null) {
        final item = _QuotationItem(
          productId: _int(product['ProductID']),
          productName: '${product['ProductName'] ?? ''}',
          productDescription:
              selectedAlternative?['SpecificationSummary']?.toString() ??
                  '${product['ProductDescription'] ?? ''}',
          pricingTier: tier,
          selectedAlternativeId: alternativeId,
          selectedAlternativeName:
              selectedAlternative?['AlternativeName']?.toString() ?? '',
          quantity: quantity,
          unitPrice: price,
          notes: notes,
          onChanged: _refreshTotals,
        );
        setState(() => _items.add(item));
      } else {
        setState(() {
          existing
            ..pricingTier = tier
            ..selectedAlternativeId = alternativeId
            ..selectedAlternativeName =
                selectedAlternative?['AlternativeName']?.toString() ?? ''
            ..productDescription = selectedAlternative?['SpecificationSummary']
                    ?.toString() ??
                '${product['ProductDescription'] ?? existing.productDescription}'
            ..notes = notes
            ..quantityController.text = '$quantity'
            ..priceController.text = '$price';
        });
      }
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_partyId == null) {
      _message('اختر العميل أولاً', error: true);
      return;
    }
    if (_items.isEmpty) {
      _message('أضف صنفاً واحداً على الأقل لعرض السعر', error: true);
      return;
    }
    if (_validUntil != null && _validUntil!.isBefore(_quotationDate)) {
      _message('تاريخ الصلاحية يجب أن يكون بعد تاريخ العرض', error: true);
      return;
    }

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'quotationDate': _quotationDate.toIso8601String(),
      'validUntil': _validUntil?.toIso8601String(),
      'partyId': _partyId,
      'warehouseId': _warehouseId,
      'opportunityId': _opportunityId,
      'discountAmount': _discount,
      'notes': _notesController.text.trim(),
      'status': _status,
      'items': _items.map((item) => item.toJson()).toList(),
    };
    try {
      final result = _isEdit
          ? await _service.update(widget.quotationId!, body)
          : await _service.create(body);
      if (!mounted) return;
      _message('${result['message'] ?? 'تم حفظ عرض السعر بنجاح'}');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'DISCOUNT_APPROVAL_REQUIRED' && _isEdit) {
        _message('${error.message}\nيمكنك إرسال طلب خصم من تفاصيل العرض.',
            error: true);
      } else {
        _message(error.message, error: true);
      }
    } catch (error) {
      if (mounted) _message('تعذر الحفظ: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===========================================================================
  // 🎨 الواجهة الرسومية العصرية (Bento FinTech Quotation UI)
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isEdit ? 'تعديل عرض السعر' : 'إنشاء عرض سعر جديد',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    _referenceNumber?.isNotEmpty == true
                        ? 'مرجع #$_referenceNumber'
                        : 'عروض الأسعار والمبيعات',
                    style:
                        GoogleFonts.cairo(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _status == 'Draft' ? 'مسودة عرض' : _status,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar:
            (_loading || _error != null) ? null : _buildStickyBottomBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? _errorState()
                : _formBody(),
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
                color: AppColors.error, size: 54),
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
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBody() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
      children: <Widget>[
        _buildHeroDashboard(),
        const SizedBox(height: 16),
        _buildPartyAndOpportunityCard(),
        const SizedBox(height: 16),
        _buildWarehouseCard(),
        const SizedBox(height: 16),
        _buildItemsModernSection(),
        const SizedBox(height: 16),
        _buildReceiptTotalsCard(),
      ],
    );
  }

  // 1️⃣ لوحة التحكم العلوية المدمجة لعرض السعر (Hero Quotation Dashboard)
  Widget _buildHeroDashboard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.navy,
            Color(0xFF1E293B),
          ],
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
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'صافي قيمة عرض السعر',
                    style: GoogleFonts.cairo(
                        fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        _money(_grand),
                        style: GoogleFonts.cairo(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ج.م',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '${_items.length}',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'بنود العرض',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.gold),
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
                child: _buildDatePill(
                  icon: Icons.calendar_today_rounded,
                  label: 'تاريخ إصدار العرض',
                  value: DateFormat('yyyy/MM/dd').format(_quotationDate),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _quotationDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (selected != null) {
                      setState(
                          () => _quotationDate = DateUtils.dateOnly(selected));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePill(
                  icon: Icons.timer_outlined,
                  label: 'صالح حتى تاريخ',
                  value: _validUntil == null
                      ? 'مفتوح الصلاحية'
                      : DateFormat('yyyy/MM/dd').format(_validUntil!),
                  isHighlighted: _validUntil != null,
                  onClear: _validUntil != null
                      ? () => setState(() => _validUntil = null)
                      : null,
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _validUntil ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (selected != null) {
                      setState(
                          () => _validUntil = DateUtils.dateOnly(selected));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.gold.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? AppColors.gold.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label,
                      style: GoogleFonts.cairo(
                          fontSize: 9.5, color: Colors.white60)),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 15, color: Colors.white60),
              )
            else
              const Icon(Icons.edit_calendar_rounded,
                  size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // 2️⃣ كارت العميل والفرصة البيعية (VIP Client & Opportunity Card)
  Widget _buildPartyAndOpportunityCard() {
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
        children: <Widget>[
          if (_partyId == null)
            InkWell(
              onTap: _selectParty,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.gold.withValues(alpha: 0.25),
                          AppColors.gold.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person_search_rounded,
                        color: AppColors.navy, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'تحديد العميل الموجه له العرض *',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _textColor,
                          ),
                        ),
                        Text(
                          'اضغط للبحث بالاسم أو الهاتف وتحميل فرص البيع',
                          style: GoogleFonts.cairo(
                              fontSize: 11.5, color: _secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'اختيار',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
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
                        _safeInitial(_partyName),
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
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  _partyName ?? '',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded,
                                  color: Colors.green, size: 16),
                            ],
                          ),
                          if (_partyPhone?.isNotEmpty == true)
                            Text(
                              '📞 $_partyPhone',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: _secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.gold.withValues(alpha: 0.15),
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _selectParty,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: Text('تغيير',
                          style: GoogleFonts.cairo(
                              fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _opportunities
                          .any((o) => _int(o['OpportunityID']) == _opportunityId)
                      ? _opportunityId
                      : null,
                  isExpanded: true,
                  dropdownColor: _cardColor,
                  decoration: _modernInputDecoration(
                    'ربط بفرصة بيع (اختياري)',
                    Icons.track_changes_rounded,
                  ),
                  items: _opportunityItems(),
                  onChanged: (int? value) {
                    if (!mounted) return;
                    setState(() => _opportunityId = value);
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int?>> _opportunityItems() {
    final seen = <int>{};
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('بدون ربط بفرصة')),
    ];
    for (final row in _opportunities) {
      final id = _int(row['OpportunityID']);
      if (id <= 0 || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem<int?>(
          value: id,
          child: Text(
            '#$id — ${row['StageNameAr'] ?? 'بدون مرحلة'} — ${_money(row['ExpectedValue'])} ج',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(fontSize: 12.5),
          ),
        ),
      );
    }
    final current = _opportunityId;
    if (current != null && !seen.contains(current)) {
      items.add(
        DropdownMenuItem<int?>(
          value: current,
          child: Text(
            '#$current — فرصة مرتبطة بالعرض',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(fontSize: 12.5),
          ),
        ),
      );
    }
    return items;
  }

  // 3️⃣ شريط تحديد المخزن (Warehouse Compact Card)
  Widget _buildWarehouseCard() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<int?>(
        initialValue: _warehouseId,
        isExpanded: true,
        dropdownColor: _cardColor,
        decoration: _modernInputDecoration(
          'المخزن المرجعي للأرصدة (اختياري)',
          Icons.warehouse_rounded,
        ),
        items: <DropdownMenuItem<int?>>[
          DropdownMenuItem<int?>(
            value: null,
            child: Text('جميع المخازن (بدون تحديد)',
                style: GoogleFonts.cairo(fontSize: 12.5)),
          ),
          ..._warehouses.map<DropdownMenuItem<int?>>((Map<String, dynamic> row) {
            return DropdownMenuItem<int?>(
              value: _int(row['WarehouseID']),
              child: Text(
                '${row['WarehouseName'] ?? ''}${'${row['BranchNameAr'] ?? ''}'.isEmpty ? '' : ' — ${row['BranchNameAr']}'}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
        onChanged: (int? value) async {
          setState(() => _warehouseId = value);
          if (_partyId != null) await _loadProducts();
        },
      ),
    );
  }

  // 4️⃣ قسم الأصناف الحديث (Bento Quotation Items)
  Widget _buildItemsModernSection() {
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
                  color: AppColors.gold.withValues(alpha: 0.18),
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
                      'بنود وأصناف عرض السعر',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: _textColor),
                    ),
                    Text(
                      _items.isEmpty
                          ? 'لم تتم إضافة أصناف للعرض بعد'
                          : 'إجمالي ${_items.length} صنف بقيمة ${_money(_total)} ج',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: _secondaryTextColor),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickProduct,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    size: 17, color: AppColors.gold),
                label: Text(
                  'إضافة صنف',
                  style: GoogleFonts.cairo(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            InkWell(
              onTap: _pickProduct,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: _isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(Icons.add_shopping_cart_rounded,
                        size: 42, color: AppColors.gold),
                    const SizedBox(height: 10),
                    Text(
                      _partyId == null
                          ? 'اختر العميل بالأعلى أولاً ثم أضف الأصناف'
                          : 'اضغط هنا لاختيار الأصناف وتحديد الفئة والبدائل',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, int idx) =>
                  _buildBentoQuotationItemCard(_items[idx], idx),
            ),
        ],
      ),
    );
  }

  Widget _buildBentoQuotationItemCard(_QuotationItem item, int idx) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${idx + 1}',
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.productName,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _buildBadge(
                          'فئة: ${_tierLabel(item.pricingTier)}',
                          AppColors.navy,
                        ),
                        if (item.selectedAlternativeName.isNotEmpty)
                          _buildBadge(
                            'البديل: ${item.selectedAlternativeName}',
                            Colors.teal.shade700,
                          ),
                      ],
                    ),
                    if (item.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '📝 ${item.notes}',
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          color: _secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تعديل الفئة أو البديل',
                visualDensity: VisualDensity.compact,
                onPressed: () => _configureProduct(
                  _productDataForItem(item),
                  existing: item,
                ),
                icon: const Icon(Icons.tune_rounded,
                    size: 19, color: AppColors.info),
              ),
              IconButton(
                tooltip: 'حذف البند',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _items.remove(item));
                  item.dispose();
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 19, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              // كبسولة الكمية المزودة بأزرار + و -
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider(_isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildStepBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (item.quantity > 1) {
                          final next = item.quantity - 1;
                          item.quantityController.text =
                              next % 1 == 0 ? next.toInt().toString() : '$next';
                        }
                      },
                    ),
                    SizedBox(
                      width: 44,
                      child: TextField(
                        controller: item.quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: GoogleFonts.cairo(
                            color: _textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    _buildStepBtn(
                      icon: Icons.add_rounded,
                      isPlus: true,
                      onTap: () {
                        final next = item.quantity + 1;
                        item.quantityController.text =
                            next % 1 == 0 ? next.toInt().toString() : '$next';
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // حقل السعر
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider(_isDark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('سعر الوحدة (ج.م)',
                          style: GoogleFonts.cairo(
                              fontSize: 9.5, color: _secondaryTextColor)),
                      TextField(
                        controller: item.priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: GoogleFonts.cairo(
                            color: _textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // إجمالي البند
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('الإجمالي',
                        style: GoogleFonts.cairo(
                            fontSize: 9.5, color: _secondaryTextColor)),
                    Text(
                      '${_money(item.total)} ج',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _isDark ? AppColors.gold : color,
        ),
      ),
    );
  }

  Widget _buildStepBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isPlus = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isPlus
              ? AppColors.gold.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isPlus ? AppColors.navy : _secondaryTextColor,
        ),
      ),
    );
  }

  // 5️⃣ ملخص الإيصال المالي والملاحظات (Receipt Totals Card)
  Widget _buildReceiptTotalsCard() {
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
                'ملخص عرض السعر والخصومات',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _textColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('إجمالي قيمة الأصناف',
                  style: GoogleFonts.cairo(
                      fontSize: 12.5, color: _secondaryTextColor)),
              Text(
                '${_money(_total)} ج.م',
                style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: GoogleFonts.cairo(
                color: _textColor, fontWeight: FontWeight.bold),
            decoration: _modernInputDecoration(
              'قيمة الخصم النقدي على العرض (ج.م)',
              Icons.discount_rounded,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
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
                  'الإجمالي النهائي لعرض السعر',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${_money(_grand)} ج.م',
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.cairo(color: _textColor, fontSize: 12.5),
            decoration: _modernInputDecoration(
              'شروط وملاحظات عرض السعر (تظهر للعميل في الطباعة)',
              Icons.notes_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'صافي العرض (${_items.length} أصناف)',
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: _secondaryTextColor),
                  ),
                  Text(
                    '${_money(_grand)} ج.م',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _isDark ? AppColors.gold : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded,
                        color: AppColors.gold),
                label: Text(
                  _saving
                      ? 'جاري الحفظ...'
                      : (_isEdit ? 'حفظ التعديلات' : 'اعتماد وحفظ العرض'),
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _modernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.goldDark, size: 19),
      filled: true,
      fillColor: _isDark
          ? Colors.white.withValues(alpha: 0.03)
          : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
      ),
    );
  }

  Map<String, dynamic> _productDataForItem(_QuotationItem item) {
    for (final product in _products) {
      if (_int(product['ProductID']) == item.productId) return product;
    }
    return <String, dynamic>{
      'ProductID': item.productId,
      'ProductName': item.productName,
      'ProductDescription': item.productDescription,
      'SuggestedSalePrice': item.unitPrice,
      'SuggestedSalePriceCClass': item.unitPrice,
      'SuggestedSalePriceElite': item.unitPrice,
    };
  }

  String _tierLabel(String tier) {
    return switch (tier) {
      'CClass' => 'ستاندرد',
      'Elite' => 'إيليت 👑',
      _ => 'بريميوم ⭐',
    };
  }

  static String _money(dynamic value) {
    return NumberFormat('#,##0.##', 'en_US').format(_num(value));
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

// =============================================================================
// 🛡️ 1. نافذة البحث عن العميل المستقلة (آمنة ضد الشاشة الحمراء)
// =============================================================================
class _QuotationPartySearchSheet extends StatefulWidget {
  final bool isDark;
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;

  const _QuotationPartySearchSheet({
    required this.isDark,
    required this.onSearch,
  });

  @override
  State<_QuotationPartySearchSheet> createState() =>
      _QuotationPartySearchSheetState();
}

class _QuotationPartySearchSheetState
    extends State<_QuotationPartySearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerSearch(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = <Map<String, dynamic>>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final list = await widget.onSearch(value);
        if (mounted) {
          setState(() {
            _results = list;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.card(widget.isDark);
    final textColor = AppColors.text(widget.isDark);
    final subColor = AppColors.textSecondary(widget.isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.80,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider(widget.isDark),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(Icons.person_search_rounded,
                    color: AppColors.gold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اختيار العميل لعرض السعر',
                    style: GoogleFonts.cairo(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _triggerSearch,
              style: GoogleFonts.cairo(color: textColor),
              decoration: InputDecoration(
                hintText: 'ابحث باسم العميل أو رقم الهاتف...',
                hintStyle: GoogleFonts.cairo(color: subColor, fontSize: 12),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.inputFill(widget.isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_searching)
              const LinearProgressIndicator(color: AppColors.gold),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _ctrl.text.trim().isEmpty
                            ? 'اكتب اسم العميل للبحث'
                            : 'لا توجد نتائج مطابقة',
                        style: GoogleFonts.cairo(color: subColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 6),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, int i) {
                        final party = _results[i];
                        final name = '${party['PartyName'] ?? 'عميل'}';
                        final phone = '${party['Phone'] ?? ''}';
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: AppColors.divider(widget.isDark)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.navy,
                            child: Text(
                              _QuotationFormScreenState._safeInitial(name),
                              style: GoogleFonts.cairo(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.cairo(
                                color: textColor, fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            phone.isEmpty ? 'بدون رقم هاتف' : '📞 $phone',
                            style:
                                GoogleFonts.cairo(color: subColor, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context, party);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 🛡️ 2. نافذة اختيار المنتج مع الصور (آمنة ضد الشاشة الحمراء)
// =============================================================================
class _QuotationProductPickerSheet extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> initialProducts;
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;

  const _QuotationProductPickerSheet({
    required this.isDark,
    required this.initialProducts,
    required this.onSearch,
  });

  @override
  State<_QuotationProductPickerSheet> createState() =>
      _QuotationProductPickerSheetState();
}

class _QuotationProductPickerSheetState
    extends State<_QuotationProductPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  late List<Map<String, dynamic>> _displayProducts;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _displayProducts = List<Map<String, dynamic>>.from(widget.initialProducts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerSearch(String value) {
    _debounce?.cancel();
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final list = await widget.onSearch(value);
        if (mounted) {
          setState(() {
            _displayProducts = list;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.card(widget.isDark);
    final textColor = AppColors.text(widget.isDark);
    final subColor = AppColors.textSecondary(widget.isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.84,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.divider(widget.isDark),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.inventory_2_rounded,
                    color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'كتالوج المنتجات لعرض السعر',
                    style: GoogleFonts.cairo(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              onChanged: _triggerSearch,
              style: GoogleFonts.cairo(color: textColor),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الوصف أو الكود...',
                hintStyle: GoogleFonts.cairo(color: subColor, fontSize: 12),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.inputFill(widget.isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_searching)
              const LinearProgressIndicator(color: AppColors.gold),
            Expanded(
              child: _displayProducts.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد منتجات متاحة',
                        style: GoogleFonts.cairo(color: subColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 6),
                      itemCount: _displayProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, int index) {
                        final row = _displayProducts[index];
                        final stock =
                            _QuotationFormScreenState._num(row['AvailableStock']);
                        final customerSpecific = row['Customer'] != null;
                        final imgId =
                            _QuotationFormScreenState._int(row['MainImageId']);
                        final price = _QuotationFormScreenState._num(
                            row['SuggestedSalePrice']);

                        return ListTile(
                          tileColor: AppColors.inputFill(widget.isDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: AppColors.divider(widget.isDark),
                            ),
                          ),
                          leading: Container(
                            width: 52,
                            height: 52,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imgId > 0
                                ? Image.network(
                                    '$baseUrl/api/product-image-by-id/$imgId',
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
                          title: Text(
                            '${row['ProductName'] ?? ''}',
                            style: GoogleFonts.cairo(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            customerSpecific
                                ? 'مخصص للعميل • ${_QuotationFormScreenState._money(price)} ج'
                                : 'من المخزن (رصيد ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)}) • ${_QuotationFormScreenState._money(price)} ج',
                            style: GoogleFonts.cairo(
                              color: customerSpecific
                                  ? Colors.purple.shade300
                                  : subColor,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'تخصيص +',
                              style: GoogleFonts.cairo(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context, row);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 🛡️ 3. نافذة تخصيص الصنف والبدائل المصنعية (آمنة 100% ضد الشاشة الحمراء)
// =============================================================================
class _ConfigureProductSheet extends StatefulWidget {
  final bool isDark;
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> alternatives;
  final _QuotationItem? existing;
  final void Function(String) onValidationError;

  const _ConfigureProductSheet({
    required this.isDark,
    required this.product,
    required this.alternatives,
    required this.existing,
    required this.onValidationError,
  });

  @override
  State<_ConfigureProductSheet> createState() => _ConfigureProductSheetState();
}

class _ConfigureProductSheetState extends State<_ConfigureProductSheet> {
  late String _tier;
  int? _alternativeId;
  Map<String, dynamic>? _selectedAlternative;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _tier = widget.existing?.pricingTier ?? 'Premium';
    _alternativeId = widget.existing?.selectedAlternativeId;
    if (_alternativeId != null) {
      for (final alt in widget.alternatives) {
        if (_QuotationFormScreenState._int(alt['AlternativeID']) ==
            _alternativeId) {
          _selectedAlternative = alt;
          break;
        }
      }
    }
    _qtyCtrl = TextEditingController(
      text: '${widget.existing?.quantity ?? 1}',
    );
    _priceCtrl = TextEditingController(
      text: '${widget.existing?.unitPrice ?? _defaultPrice()}',
    );
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _defaultPrice() {
    final source = _selectedAlternative ?? widget.product;
    if (_selectedAlternative != null) {
      return switch (_tier) {
        'CClass' =>
          _QuotationFormScreenState._num(source['SuggestedSalePriceCClass']),
        'Elite' =>
          _QuotationFormScreenState._num(source['SuggestedSalePriceElite']),
        _ =>
          _QuotationFormScreenState._num(source['SuggestedSalePricePremium']),
      };
    }
    return switch (_tier) {
      'CClass' =>
        _QuotationFormScreenState._num(source['SuggestedSalePriceCClass']),
      'Elite' =>
        _QuotationFormScreenState._num(source['SuggestedSalePriceElite']),
      _ => _QuotationFormScreenState._num(source['SuggestedSalePrice']),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.card(widget.isDark);
    final textColor = AppColors.text(widget.isDark);
    final subColor = AppColors.textSecondary(widget.isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.divider(widget.isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.product['ProductName'] ?? widget.existing?.productName ?? ''}',
                    style: GoogleFonts.cairo(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                          value: 'CClass', label: Text('ستاندرد')),
                      ButtonSegment<String>(
                          value: 'Premium', label: Text('بريميوم ⭐')),
                      ButtonSegment<String>(
                          value: 'Elite', label: Text('إيليت 👑')),
                    ],
                    selected: <String>{_tier},
                    onSelectionChanged: (Set<String> value) {
                      setState(() {
                        _tier = value.first;
                        _priceCtrl.text = '${_defaultPrice()}';
                      });
                    },
                  ),
                  if (widget.alternatives.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      initialValue: _alternativeId,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      decoration: InputDecoration(
                        labelText: 'البديل المصنعي',
                        labelStyle: GoogleFonts.cairo(color: subColor),
                        prefixIcon: const Icon(Icons.factory_rounded,
                            color: AppColors.goldDark),
                        filled: true,
                        fillColor: AppColors.inputFill(widget.isDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('المنتج الأساسي'),
                        ),
                        ...widget.alternatives.map((Map<String, dynamic> alt) {
                          return DropdownMenuItem<int?>(
                            value: _QuotationFormScreenState._int(
                                alt['AlternativeID']),
                            child: Text('${alt['AlternativeName'] ?? ''}'),
                          );
                        }),
                      ],
                      onChanged: (int? value) {
                        setState(() {
                          _alternativeId = value;
                          _selectedAlternative = value == null
                              ? null
                              : widget.alternatives.firstWhere(
                                  (Map<String, dynamic> alt) =>
                                      _QuotationFormScreenState._int(
                                          alt['AlternativeID']) ==
                                      value,
                                );
                          _priceCtrl.text = '${_defaultPrice()}';
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          style: GoogleFonts.cairo(
                              color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'الكمية *',
                            prefixIcon: const Icon(
                                Icons.production_quantity_limits_rounded,
                                color: AppColors.goldDark),
                            filled: true,
                            fillColor: AppColors.inputFill(widget.isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          style: GoogleFonts.cairo(
                              color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'سعر الوحدة *',
                            prefixIcon: const Icon(Icons.local_offer_rounded,
                                color: AppColors.goldDark),
                            filled: true,
                            fillColor: AppColors.inputFill(widget.isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.cairo(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'ملاحظات خاصة بهذا البند',
                      prefixIcon: const Icon(Icons.notes_rounded,
                          color: AppColors.goldDark),
                      filled: true,
                      fillColor: AppColors.inputFill(widget.isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final quantity = double.tryParse(
                          _qtyCtrl.text.replaceAll(',', ''),
                        );
                        final price = double.tryParse(
                          _priceCtrl.text.replaceAll(',', ''),
                        );
                        if (quantity == null ||
                            quantity <= 0 ||
                            price == null ||
                            price < 0) {
                          widget.onValidationError('راجع الكمية والسعر');
                          return;
                        }
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context, <String, dynamic>{
                          'tier': _tier,
                          'alternativeId': _alternativeId,
                          'selectedAlternative': _selectedAlternative,
                          'quantity': quantity,
                          'price': price,
                          'notes': _notesCtrl.text.trim(),
                        });
                      },
                      icon: const Icon(Icons.check_circle_rounded,
                          color: AppColors.gold),
                      label: Text(
                        widget.existing == null
                            ? 'إضافة البند للعرض'
                            : 'حفظ تعديلات البند',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuotationItem {
  final int quotationDetailId;
  final int productId;
  final String productName;
  String productDescription;
  String pricingTier;
  int? selectedAlternativeId;
  String selectedAlternativeName;
  String notes;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final VoidCallback onChanged;

  _QuotationItem({
    this.quotationDetailId = 0,
    required this.productId,
    required this.productName,
    this.productDescription = '',
    this.pricingTier = 'Premium',
    this.selectedAlternativeId,
    this.selectedAlternativeName = '',
    double quantity = 1,
    double unitPrice = 0,
    this.notes = '',
    required this.onChanged,
  })  : quantityController = TextEditingController(text: '$quantity'),
        priceController = TextEditingController(text: '$unitPrice') {
    quantityController.addListener(onChanged);
    priceController.addListener(onChanged);
  }

  double get quantity =>
      double.tryParse(quantityController.text.replaceAll(',', '')) ?? 0;
  double get unitPrice =>
      double.tryParse(priceController.text.replaceAll(',', '')) ?? 0;
  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'quotationDetailId': quotationDetailId,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'pricingTier': pricingTier,
      'selectedAlternativeId': selectedAlternativeId,
      'notes': notes,
    };
  }

  void dispose() {
    quantityController
      ..removeListener(onChanged)
      ..dispose();
    priceController
      ..removeListener(onChanged)
      ..dispose();
  }
}