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
      final opportunities = ((lookups['opportunities'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      if (!mounted) return;
      setState(() {
        _opportunities = opportunities;
        // لو الفرصة الحالية غير موجودة في القائمة الجديدة، أعد ضبطها لـ null لتجنب assert
        if (_opportunityId != null &&
            !_opportunities.any((o) => _int(o['OpportunityID']) == _opportunityId)) {
          // احتفظ بالقيمة — سيضيفها _opportunityItems كعنصر احتياطي، لكن لو كانت null خلاص
        }
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

  Future<void> _selectParty() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    bool searching = false;
    Timer? debounce;
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> search(String value) async {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 350), () async {
                if (value.trim().isEmpty) {
                  if (sheetContext.mounted) {
                    setSheetState(() => results = <Map<String, dynamic>>[]);
                  }
                  return;
                }
                if (!sheetContext.mounted) return;
                if (!sheetContext.mounted) return;
                setSheetState(() => searching = true);
                try {
                  final data = await _service.getLookups(search: value.trim());
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    results = ((data['parties'] as List?) ?? const <dynamic>[])
                        .map<Map<String, dynamic>>(_map)
                        .toList();
                    searching = false;
                  });
                } catch (_) {
                  if (sheetContext.mounted) {
                    setSheetState(() => searching = false);
                  }
                }
              });
            }

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.72,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider(_isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: search,
                      style: GoogleFonts.cairo(color: _textColor),
                      decoration: _decoration(
                        'ابحث باسم العميل أو الهاتف',
                        Icons.person_search_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (searching)
                      const LinearProgressIndicator(color: AppColors.gold),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                'اكتب للبحث عن العميل',
                                style: GoogleFonts.cairo(
                                    color: _secondaryTextColor),
                              ),
                            )
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) => Divider(
                                color: AppColors.divider(_isDark),
                              ),
                              itemBuilder: (_, int index) {
                                final party = results[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_rounded),
                                  ),
                                  title: Text(
                                    '${party['PartyName'] ?? ''}',
                                    style: GoogleFonts.cairo(
                                      color: _textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${party['Phone'] ?? ''}',
                                    style: GoogleFonts.cairo(
                                      color: _secondaryTextColor,
                                    ),
                                  ),
                                  onTap: () =>
                                      Navigator.pop(sheetContext, party),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    debounce?.cancel();
    Future.delayed(const Duration(milliseconds: 350), () {
      try { controller.dispose(); } catch (_) {}
    });
    if (chosen == null) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      return;
    }
    if (!mounted) return;

    // إزالة الأصناف من الشجرة أولاً ثم تحرير الـ controllers الخاصة بها.
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
      _message('اختر العميل أولاً', error: true);
      return;
    }
    _productSearchController.clear();
    await _loadProducts();
    if (!mounted) return;

    var displayProducts = List<Map<String, dynamic>>.from(_products);
    var searching = false;
    Timer? debounce;
    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            void search(String value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 350), () async {
                if (!sheetContext.mounted) return;
                setSheetState(() => searching = true);
                try {
                  final rows = await _service.getProducts(
                    partyId: _partyId!,
                    warehouseId: _warehouseId,
                    search: value.trim(),
                  );
                  if (!sheetContext.mounted) return;
                  setSheetState(() {
                    displayProducts =
                        rows.map<Map<String, dynamic>>(_map).toList();
                    searching = false;
                  });
                } catch (_) {
                  if (sheetContext.mounted) {
                    setSheetState(() => searching = false);
                  }
                }
              });
            }

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.80,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider(_isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'اختيار صنف',
                            style: GoogleFonts.cairo(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _productSearchController,
                      onChanged: search,
                      style: GoogleFonts.cairo(color: _textColor),
                      decoration: _decoration(
                        'بحث بالاسم أو الوصف أو الكود',
                        Icons.search_rounded,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (searching)
                      const LinearProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 2),
                    Expanded(
                      child: displayProducts.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد منتجات متاحة',
                                style: GoogleFonts.cairo(
                                  color: _secondaryTextColor,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: displayProducts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, int index) {
                                final row = displayProducts[index];
                                final stock = _num(row['AvailableStock']);
                                final customerSpecific =
                                    row['Customer'] != null;
                                return ListTile(
                                  tileColor: AppColors.inputFill(_isDark),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    side: BorderSide(
                                      color: AppColors.divider(_isDark),
                                    ),
                                  ),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: AppColors.card(_isDark),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: _int(row['MainImageId']) > 0
                                        ? Image.network(
                                            '$baseUrl/api/product-image-by-id/${_int(row['MainImageId'])}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.inventory_2_outlined,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.inventory_2_outlined,
                                          ),
                                  ),
                                  title: Text(
                                    '${row['ProductName'] ?? ''}',
                                    style: GoogleFonts.cairo(
                                      color: _textColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  subtitle: Text(
                                    customerSpecific
                                        ? 'مخصص للعميل'
                                        : 'من المخزن · رصيد ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)}',
                                    style: GoogleFonts.cairo(
                                      color: customerSpecific
                                          ? Colors.purple.shade300
                                          : _secondaryTextColor,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.goldDark,
                                  ),
                                  onTap: () => Navigator.pop(sheetContext, row),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    debounce?.cancel();
    if (product != null) await _configureProduct(product);
  }

  Future<void> _configureProduct(
    Map<String, dynamic> product, {
    _QuotationItem? existing,
  }) async {
    final alternatives =
        await _service.getAlternatives(_int(product['ProductID']));
    if (!mounted) return;
    String tier = existing?.pricingTier ?? 'Premium';
    int? alternativeId = existing?.selectedAlternativeId;
    final quantityController = TextEditingController(
      text: '${existing?.quantity ?? 1}',
    );
    final priceController = TextEditingController();
    final notesController = TextEditingController(text: existing?.notes ?? '');

    Map<String, dynamic>? selectedAlternative;
    if (alternativeId != null) {
      for (final raw in alternatives) {
        final value = _map(raw);
        if (_int(value['AlternativeID']) == alternativeId) {
          selectedAlternative = value;
          break;
        }
      }
    }

    double defaultPrice() {
      final source = selectedAlternative ?? product;
      if (selectedAlternative != null) {
        return switch (tier) {
          'CClass' => _num(source['SuggestedSalePriceCClass']),
          'Elite' => _num(source['SuggestedSalePriceElite']),
          _ => _num(source['SuggestedSalePricePremium']),
        };
      }
      return switch (tier) {
        'CClass' => _num(source['SuggestedSalePriceCClass']),
        'Elite' => _num(source['SuggestedSalePriceElite']),
        _ => _num(source['SuggestedSalePrice']),
      };
    }

    priceController.text = '${existing?.unitPrice ?? defaultPrice()}';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider(_isDark),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          '${product['ProductName'] ?? existing?.productName ?? ''}',
                          style: GoogleFonts.cairo(
                            color: _textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 13),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                                value: 'CClass', label: Text('ستاندرد')),
                            ButtonSegment<String>(
                                value: 'Premium', label: Text('بريميوم')),
                            ButtonSegment<String>(
                                value: 'Elite', label: Text('إيليت')),
                          ],
                          selected: <String>{tier},
                          onSelectionChanged: (Set<String> value) {
                            setSheetState(() {
                              tier = value.first;
                              priceController.text = '${defaultPrice()}';
                            });
                          },
                        ),
                        if (alternatives.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int?>(
                            initialValue: alternativeId,
                            isExpanded: true,
                            decoration: _decoration(
                                'البديل المصنعي', Icons.factory_rounded),
                            dropdownColor: _cardColor,
                            items: <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('المنتج الأساسي'),
                              ),
                              ...alternatives
                                  .map<DropdownMenuItem<int?>>((dynamic raw) {
                                final alt = _map(raw);
                                return DropdownMenuItem<int?>(
                                  value: _int(alt['AlternativeID']),
                                  child:
                                      Text('${alt['AlternativeName'] ?? ''}'),
                                );
                              }),
                            ],
                            onChanged: (int? value) {
                              setSheetState(() {
                                alternativeId = value;
                                selectedAlternative = value == null
                                    ? null
                                    : alternatives
                                        .map<Map<String, dynamic>>(_map)
                                        .firstWhere(
                                          (Map<String, dynamic> alt) =>
                                              _int(alt['AlternativeID']) ==
                                              value,
                                        );
                                priceController.text = '${defaultPrice()}';
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: quantityController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]')),
                                ],
                                style: GoogleFonts.cairo(color: _textColor),
                                decoration: _decoration(
                                    'الكمية *', Icons.production_quantity_limits_rounded),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]')),
                                ],
                                style: GoogleFonts.cairo(color: _textColor),
                                decoration: _decoration(
                                    'السعر *', Icons.local_offer_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          style: GoogleFonts.cairo(color: _textColor),
                          decoration:
                              _decoration('ملاحظات الصنف', Icons.notes_rounded),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 49,
                          child: FilledButton.icon(
                            onPressed: () {
                              final quantity = double.tryParse(
                                quantityController.text.replaceAll(',', ''),
                              );
                              final price = double.tryParse(
                                priceController.text.replaceAll(',', ''),
                              );
                              if (quantity == null ||
                                  quantity <= 0 ||
                                  price == null ||
                                  price < 0) {
                                _message('راجع الكمية والسعر', error: true);
                                return;
                              }
                              Navigator.pop(sheetContext, true);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              existing == null ? 'إضافة الصنف' : 'حفظ التعديل',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (confirmed == true) {
      final quantity =
          double.parse(quantityController.text.replaceAll(',', ''));
      final price = double.parse(priceController.text.replaceAll(',', ''));
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
          notes: notesController.text.trim(),
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
            ..notes = notesController.text.trim()
            ..quantityController.text = '$quantity'
            ..priceController.text = '$price';
        });
      }
    }

    quantityController.dispose();
    priceController.dispose();
    notesController.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 11.5),
      prefixIcon: Icon(icon, color: AppColors.goldDark, size: 19),
      filled: true,
      fillColor: AppColors.inputFill(_isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_partyId == null) {
      _message('اختر العميل', error: true);
      return;
    }
    if (_items.isEmpty) {
      _message('أضف صنفاً واحداً على الأقل', error: true);
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
      _message('${result['message'] ?? 'تم حفظ عرض السعر'}');
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(
            _isEdit ? 'تعديل عرض السعر' : 'عرض سعر جديد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          centerTitle: true,
          actions: <Widget>[
            if (!_loading)
              IconButton(
                tooltip: 'حفظ',
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
              ),
          ],
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 50),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: _secondaryTextColor),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _formBody() {
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            100 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: <Widget>[
              _summaryHero(),
              const SizedBox(height: 14),
              _section(
                title: 'بيانات العرض',
                icon: Icons.description_rounded,
                child: _quotationFields(),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'العميل والفرصة',
                icon: Icons.person_rounded,
                child: _partyFields(),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'الأصناف',
                icon: Icons.inventory_2_rounded,
                trailing: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _pickProduct,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text('إضافة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                ),
                child: _itemsList(),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'الإجماليات والملاحظات',
                icon: Icons.calculate_rounded,
                child: _totalsFields(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _saving ? 'جاري الحفظ...' : 'حفظ عرض السعر',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.description_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _referenceNumber?.isNotEmpty == true
                      ? _referenceNumber!
                      : 'عرض سعر جديد',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _partyName ?? 'اختر العميل وأضف الأصناف',
                  style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${_money(_grand)} ج.م',
                style: GoogleFonts.cairo(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${_items.length} صنف',
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.goldDark, size: 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium(_isDark).copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _quotationFields() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _dateField(
                label: 'تاريخ العرض',
                value: _quotationDate,
                onChanged: (DateTime value) =>
                    setState(() => _quotationDate = value),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateField(
                label: 'صالح حتى',
                value: _validUntil,
                nullable: true,
                onChanged: (DateTime value) =>
                    setState(() => _validUntil = value),
                onClear: () => setState(() => _validUntil = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        DropdownButtonFormField<int?>(
          initialValue: _warehouseId,
          isExpanded: true,
          dropdownColor: _cardColor,
          decoration: _decoration('المخزن (اختياري)', Icons.warehouse_rounded),
          items: <DropdownMenuItem<int?>>[
            const DropdownMenuItem<int?>(
                value: null, child: Text('بدون تحديد')),
            ..._warehouses
                .map<DropdownMenuItem<int?>>((Map<String, dynamic> row) {
              return DropdownMenuItem<int?>(
                value: _int(row['WarehouseID']),
                child: Text(
                  '${row['WarehouseName'] ?? ''}${'${row['BranchNameAr'] ?? ''}'.isEmpty ? '' : ' — ${row['BranchNameAr']}'}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (int? value) async {
            setState(() => _warehouseId = value);
            if (_partyId != null) await _loadProducts();
          },
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
    bool nullable = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (selected != null) onChanged(DateUtils.dateOnly(selected));
      },
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.calendar_month_rounded,
                color: AppColors.goldDark, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                        color: _secondaryTextColor, fontSize: 9),
                  ),
                  Text(
                    value == null
                        ? 'غير محدد'
                        : DateFormat('yyyy/MM/dd').format(value),
                    style: GoogleFonts.cairo(
                      color: _textColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (nullable && value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 17),
              ),
          ],
        ),
      ),
    );
  }

  Widget _partyFields() {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: _selectParty,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _partyId == null
                    ? AppColors.warning.withValues(alpha: 0.45)
                    : AppColors.divider(_isDark),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.person_search_rounded,
                    color: AppColors.goldDark),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _partyName ?? 'اختر العميل *',
                        style: AppTextStyles.titleMedium(_isDark).copyWith(
                          color: _partyName == null
                              ? _secondaryTextColor
                              : _textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_partyPhone?.isNotEmpty == true)
                        Text(
                          _partyPhone!,
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded),
              ],
            ),
          ),
        ),
        if (_partyId != null) ...<Widget>[
          const SizedBox(height: 11),
          DropdownButtonFormField<int?>(
            // بدون ValueKey — تغيير الـ key كان يسبب _dependents.isEmpty عند اختيار عميل جديد
            initialValue: _opportunities.any((o) => _int(o['OpportunityID']) == _opportunityId)
                ? _opportunityId
                : null,
            isExpanded: true,
            dropdownColor: _cardColor,
            decoration: _decoration(
                'فرصة البيع (اختياري)', Icons.track_changes_rounded),
            items: _opportunityItems(),
            onChanged: (int? value) {
              if (!mounted) return;
              setState(() => _opportunityId = value);
            },
          ),
        ],
      ],
    );
  }

  /// بناء قائمة الفرص بشكل آمن.
  ///
  /// [DropdownButtonFormField] يفرض (عبر assert) أن تقابل القيمة الحالية
  /// عنصراً واحداً بالضبط. لذلك نتخلص من المكرر، ونضيف عنصراً احتياطياً
  /// للقيمة المحفوظة إن لم تكن ضمن الفرص المُحمّلة، وإلا انهار البناء
  /// بشاشة حمراء.
  List<DropdownMenuItem<int?>> _opportunityItems() {
    final seen = <int>{};
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('بدون ربط')),
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
          ),
        ),
      );
    }
    return items;
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

  Widget _itemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: <Widget>[
            Icon(Icons.inventory_2_outlined,
                color: _secondaryTextColor, size: 42),
            const SizedBox(height: 8),
            Text(
              _partyId == null ? 'اختر العميل أولاً' : 'لم تتم إضافة أصناف',
              style: GoogleFonts.cairo(color: _secondaryTextColor),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _items.asMap().entries.map<Widget>((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.divider(_isDark)),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.cairo(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: _textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_tierLabel(item.pricingTier)}${item.selectedAlternativeName.isEmpty ? '' : ' · ${item.selectedAlternativeName}'}',
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _configureProduct(
                      _productDataForItem(item),
                      existing: item,
                    ),
                    icon: const Icon(Icons.edit_rounded, color: AppColors.info),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      // إزالة الصنف من الشجرة أولاً ثم تحرير الـ controllers.
                      setState(() => _items.remove(item));
                      item.dispose();
                    },
                    icon: const Icon(Icons.delete_rounded,
                        color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: item.quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: GoogleFonts.cairo(color: _textColor, fontSize: 12),
                      decoration: _decoration('الكمية',
                          Icons.production_quantity_limits_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: item.priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: GoogleFonts.cairo(color: _textColor, fontSize: 12),
                      decoration:
                          _decoration('السعر', Icons.local_offer_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'الإجمالي',
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          '${_money(item.total)} ج',
                          style: GoogleFonts.cairo(
                            color: AppColors.goldDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
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
      }).toList(),
    );
  }

  String _tierLabel(String tier) {
    return switch (tier) {
      'CClass' => 'ستاندرد',
      'Elite' => 'إيليت',
      _ => 'بريميوم',
    };
  }

  Widget _totalsFields() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
                child:
                    _totalTile('إجمالي الأصناف', _total, AppColors.navyLight)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _totalTile('الإجمالي النهائي', _grand, AppColors.goldDark)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: GoogleFonts.cairo(color: _textColor),
          decoration: _decoration('قيمة الخصم', Icons.discount_rounded),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 4,
          style: GoogleFonts.cairo(color: _textColor),
          decoration: _decoration('ملاحظات عرض السعر', Icons.notes_rounded),
        ),
      ],
    );
  }

  Widget _totalTile(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style:
                  GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 9.5)),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              '${_money(value)} ج.م',
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _money(dynamic value) {
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
