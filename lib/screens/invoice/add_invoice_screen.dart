import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants.dart';
import '../../services/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/permission_service.dart';
import '../../services/inventory_service.dart';
import '../../services/invoice_service.dart';
import '../../core/network/api_client.dart';
import '../../widgets/crm_design_system.dart';
import 'invoice_details_screen.dart';

class AddInvoiceScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? invoiceId;
  final String initialType; // Sale | Purchase

  const AddInvoiceScreen({
    super.key,
    required this.userId,
    required this.username,
    this.invoiceId,
    this.initialType = 'Sale',
  });

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  bool _loading = true;
  bool _saving = false;
  String _invoiceType = 'Sale';

  // Lookups
  List<dynamic> _warehouses = [];
  List<dynamic> _branches = [];
  List<dynamic> _cashBoxes = [];
  List<dynamic> _availableProducts = [];
  List<dynamic> _advances = [];

  // Selected
  Map<String, dynamic>? _selectedParty;
  int? _selectedWarehouseId;
  int? _selectedBranchId;
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  String _paymentMethod = 'Cash';
  int? _selectedCashBoxId;

  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchPartyCtrl = TextEditingController();
  final _searchProductCtrl = TextEditingController();
  final _discountPctCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');

  // Original values for edit mode
  double _originalPaid = 0;
  double _originalGrand = 0;
  bool _serverCanFullEdit = false;
  bool _serverCanLimitedEdit = false;
  String? _invoiceStatus;

  bool get _canFullEdit =>
      isEdit && PermissionService().canFullEditInvoices && _serverCanFullEdit;
  bool get _canLimitedEdit =>
      isEdit && (_serverCanLimitedEdit || _canFullEdit);

  List<_InvoiceItem> _items = [];
  List<_ChargeItem> _charges = [];
  Set<int> _selectedAdvanceIds = {};

  bool get _isDark => ThemeService().isDarkMode;
  bool get isEdit => widget.invoiceId != null;
  bool get isPurchase => _invoiceType == 'Purchase';

  // دوال مساعدة آمنة لمنع الشاشة الحمراء بسبب اختلاف أنواع البيانات من الـ API
  static double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static String _safeInitial(String? text, [String fallback = 'ع']) {
    final clean = (text ?? '').trim();
    if (clean.isEmpty) return fallback;
    return clean.substring(0, 1);
  }

  double get _totalAmount => _items.fold(0.0, (sum, it) => sum + it.total);
  double get _discountAmount {
    final pct = double.tryParse(_discountPctCtrl.text) ?? 0;
    if (pct > 0) return _totalAmount * (pct / 100);
    return 0;
  }

  double get _netTotal => _totalAmount - _discountAmount;
  double get _chargesTotal => _charges.fold(0.0, (sum, ch) => sum + ch.amount);
  double get _grandTotal => _netTotal + _chargesTotal;
  double get _advanceTotal => _advances
      .where((a) =>
          _selectedAdvanceIds.contains(_safeInt(a['ChargeId'] ?? a['ChargeID'])))
      .fold(0.0, (sum, a) => sum + _safeDouble(a['ChargeAmount']));
  double get _paidAmount => double.tryParse(_paidCtrl.text) ?? 0;
  double get _remaining {
    if (isEdit) {
      return _grandTotal - _originalPaid;
    }
    return _grandTotal - _advanceTotal - _paidAmount;
  }

  @override
  void initState() {
    super.initState();
    _invoiceType = widget.initialType;
    _discountPctCtrl.addListener(_onTotalsChanged);
    _paidCtrl.addListener(_onTotalsChanged);
    _loadLookups();
  }

  void _onTotalsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    _searchPartyCtrl.dispose();
    _searchProductCtrl.dispose();
    _discountPctCtrl.removeListener(_onTotalsChanged);
    _discountPctCtrl.dispose();
    _paidCtrl.removeListener(_onTotalsChanged);
    _paidCtrl.dispose();
    for (final it in _items) {
      it.dispose();
    }
    for (final ch in _charges) {
      ch.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() => _loading = true);
    try {
      List<dynamic> branches = [];
      List<dynamic> warehouses = [];
      List<dynamic> cashBoxes = [];

      try {
        branches = await InventoryService.getBranches();
      } catch (_) {}
      try {
        warehouses = await InventoryService.getAllWarehouses();
      } catch (_) {}

      try {
        http.Response res =
            await http.get(Uri.parse('$baseUrl/api/cashbox/active'));
        if (res.statusCode == 200) {
          cashBoxes = jsonDecode(res.body) as List;
        } else {
          final fallback = await http.get(Uri.parse('$baseUrl/api/cashbox'));
          if (fallback.statusCode == 200) {
            final all = jsonDecode(fallback.body) as List;
            cashBoxes = all
                .where((c) =>
                    c['IsActive'] == true ||
                    c['IsActive'] == 1 ||
                    c['IsActive'] == null)
                .toList();
          }
        }
      } catch (_) {
        try {
          final fallback = await http.get(Uri.parse('$baseUrl/api/cashbox'));
          if (fallback.statusCode == 200) {
            cashBoxes = jsonDecode(fallback.body) as List;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _warehouses = warehouses;
        _cashBoxes = cashBoxes;
        if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
          _selectedWarehouseId = _safeInt(
              _warehouses.first['WarehouseID'] ??
                  _warehouses.first['WarehouseId']);
        }
        _loading = false;
      });
      if (isEdit) await _loadForEdit();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadForEdit() async {
    try {
      final data =
          await InvoiceService.instance.getEditModel(widget.invoiceId!);
      final header = Map<String, dynamic>.from(data['header'] as Map? ?? {});
      final details = (data['details'] as List?) ?? const [];
      final charges = (data['charges'] as List?) ?? const [];
      final capabilities = Map<String, dynamic>.from(
        data['capabilities'] as Map? ?? {},
      );
      if (!mounted) return;

      for (final it in _items) {
        it.dispose();
      }
      for (final ch in _charges) {
        ch.dispose();
      }

      setState(() {
        _serverCanFullEdit = capabilities['canFullEdit'] == true;
        _serverCanLimitedEdit = capabilities['canLimitedEdit'] == true;
        _invoiceStatus = header['InvoiceStatus']?.toString();
        _invoiceType = header['TransactionType']?.toString() ?? _invoiceType;
        _refCtrl.text = header['ReferenceNumber']?.toString() ?? '';
        _notesCtrl.text = header['Notes']?.toString() ?? '';
        final whId = header['WarehouseID'] ?? header['WarehouseId'];
        if (whId != null) _selectedWarehouseId = _safeInt(whId);
        _transactionDate = header['TransactionDate'] != null
            ? DateTime.tryParse(header['TransactionDate'].toString()) ??
                DateTime.now()
            : DateTime.now();
        _dueDate = header['DueDate'] != null
            ? DateTime.tryParse(header['DueDate'].toString())
            : null;
        _paymentMethod = header['PaymentMethod']?.toString() ?? 'Cash';
        _discountPctCtrl.text =
            _safeDouble(header['DiscountPercentage']).toString();
        _originalPaid = _safeDouble(header['PaidAmount']);
        _originalGrand = _safeDouble(header['GrandTotal']);

        final partyId = header['PartyID'] ?? header['PartyId'];
        final partyName = header['PartyName'] ?? header['SupplierName'] ?? '';
        if (partyId != null) {
          _selectedParty = {
            'PartyID': _safeInt(partyId),
            'PartyName': partyName.toString(),
            'Phone': (header['Phone'] ?? '').toString(),
          };
        }

        _items = details.map((raw) {
          final d = Map<String, dynamic>.from(raw as Map);
          return _InvoiceItem(
            detailId: _safeInt(d['DetailID'] ?? d['DetailId']),
            productId: _safeInt(d['ProductID'] ?? d['ProductId']),
            productName: (d['ProductName'] ?? '').toString(),
            productDescription:
                (d['SpecificationSummary'] ?? d['ProductDescription'] ?? '')
                    .toString(),
            quantity: _safeDouble(d['Quantity'] ?? 1),
            unitPrice: _safeDouble(d['UnitPrice']),
            pricingTier: (d['PricingTier'] ?? 'Premium').toString(),
            selectedAlternativeId:
                d['SelectedAlternativeID'] ?? d['SelectedAlternativeId'],
            availableStock: _safeInt(d['AvailableStock']),
            isShowroom: d['Customer'] == null,
            onChanged: _onTotalsChanged,
            isEditMode: !_canFullEdit,
          );
        }).toList();

        _charges = charges.map((raw) {
          final c = Map<String, dynamic>.from(raw as Map);
          return _ChargeItem(
            chargeId: _safeInt(c['ChargeID'] ?? c['ChargeId']),
            chargeType: (c['ChargeType'] ?? 'Other').toString(),
            description: (c['ChargeDescription'] ?? '').toString(),
            amount: _safeDouble(c['ChargeAmount']),
            onChanged: _onTotalsChanged,
            isEditMode: true,
            isNew: false,
          );
        }).toList();
      });

      if ((_invoiceStatus == 'Cancelled' || _invoiceStatus == 'Paid') &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكن تعديل فاتورة ملغية أو مسددة بالكامل',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<List<dynamic>> _searchParties(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final api = ApiClient.instance;
      final res =
          await api.get('/api/clients/search', query: {'q': query.trim()});
      if (res.statusCode == 200) {
        final body = api.decode(res);
        if (body is List) return body;
        if (body is Map && body['data'] is List) return body['data'] as List;
      }
      final fallback = await http.get(Uri.parse(
          '$baseUrl/api/clients/search?q=${Uri.encodeComponent(query.trim())}'));
      if (fallback.statusCode == 200) {
        final decoded = jsonDecode(fallback.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _searchProducts(String query) async {
    if (_selectedWarehouseId == null) return [];
    if (query.trim().isEmpty) return [];
    try {
      final api = ApiClient.instance;
      final res = await api.get('/api/products', query: {
        'search': query.trim(),
        'warehouseId': _selectedWarehouseId,
      });
      if (res.statusCode == 200) {
        final body = api.decode(res);
        if (body is List) return body;
        if (body is Map && body['data'] is List) return body['data'] as List;
      }
      String url =
          '$baseUrl/api/products?search=${Uri.encodeComponent(query.trim())}';
      if (_selectedWarehouseId != null) {
        url += '&warehouseId=$_selectedWarehouseId';
      }
      final fallback = await http.get(Uri.parse(url));
      if (fallback.statusCode == 200) {
        final decoded = jsonDecode(fallback.body);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadAdvances(int partyId) async {
    if (partyId <= 0) return;
    try {
      final res = await http.get(Uri.parse(
          '$baseUrl/api/clients/$partyId/advances?unappliedOnly=true'));
      if (res.statusCode == 200 && mounted) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() => _advances = decoded);
        }
      }
    } catch (_) {}
  }

  void _addProduct(Map<String, dynamic> prod) {
    final pid = _safeInt(prod['ProductID'] ?? prod['ProductId']);
    if (pid != 0 && _items.any((it) => it.productId == pid)) return;

    String tier = 'Premium';
    double price = 0;
    final pType = '${prod['PricingType'] ?? ''}'.toLowerCase();
    if (pType.contains('cclass') || pType.contains('standard')) {
      tier = 'CClass';
      price = isPurchase
          ? _safeDouble(prod['PurchasePriceCClass'] ?? prod['PurchasePrice'])
          : _safeDouble(
              prod['SuggestedSalePriceCClass'] ?? prod['SuggestedSalePrice']);
    } else if (pType.contains('elite')) {
      tier = 'Elite';
      price = isPurchase
          ? _safeDouble(prod['PurchasePriceElite'] ?? prod['PurchasePrice'])
          : _safeDouble(
              prod['SuggestedSalePriceElite'] ?? prod['SuggestedSalePrice']);
    } else {
      tier = 'Premium';
      price = isPurchase
          ? _safeDouble(prod['PurchasePrice'])
          : _safeDouble(prod['SuggestedSalePrice']);
    }

    setState(() {
      _items.add(_InvoiceItem(
        productId: pid,
        productName: (prod['ProductName'] ?? 'صنف بدون اسم').toString(),
        productDescription: (prod['ProductDescription'] ?? '').toString(),
        quantity: 1,
        unitPrice: price,
        pricingTier: tier,
        availableStock: _safeInt(prod['StockQuantity'] ?? prod['QTY']),
        isShowroom: prod['Customer'] == null,
        onChanged: _onTotalsChanged,
        isEditMode: false,
      ));
    });
  }

  // ===========================================================================
  // 🚀 نوافذ البحث المنبثقة (محمية 100% ضد الشاشة الحمراء)
  // ===========================================================================

  Future<void> _openPartySearchSheet() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PartySearchSheetWidget(
        isDark: _isDark,
        onSearch: _searchParties,
      ),
    );

    if (picked != null && mounted) {
      final partyId =
          _safeInt(picked['PartyID'] ?? picked['PartyId'] ?? picked['id']);
      setState(() {
        _selectedParty = picked;
        _selectedAdvanceIds.clear();
        _advances = [];
      });
      await _loadAdvances(partyId);
    }
  }

  Future<void> _openProductSearchSheet() async {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار المخزن أولاً قبل إضافة الأصناف',
              style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductSearchSheetWidget(
        isDark: _isDark,
        isPurchase: isPurchase,
        initialProducts: _availableProducts,
        isProductAdded: (pid) => _items.any((it) => it.productId == pid),
        onSearch: (q) async {
          final list = await _searchProducts(q);
          _availableProducts = list;
          return list;
        },
        onAddProduct: (prod) {
          _addProduct(prod);
        },
        addedCountGetter: () => _items.length,
      ),
    );
  }

  Future<String?> _askFullEditReason() async {
    String reasonText = '';
    final newItems = _items.where((e) => e.detailId == 0).length;
    final newCharges = _charges.where((e) => e.isNew).length;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.edit_note_rounded, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تأكيد التعديل الكامل',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.25)),
                  ),
                  child: Text(
                    'سيتم تحديث الأصناف والإجماليات والمخزون وتسجيل نسخة كاملة في سجل التدقيق.\n'
                    'الأصناف الحالية: ${_items.length} • الجديدة: $newItems • الرسوم الجديدة: $newCharges\n'
                    'الإجمالي: ${NumberFormat('#,##0.00').format(_originalGrand)} ← ${NumberFormat('#,##0.00').format(_grandTotal)} ج',
                    style: GoogleFonts.cairo(fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  maxLines: 3,
                  autofocus: true,
                  onChanged: (v) => reasonText = v,
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'سبب التعديل *',
                    labelStyle: GoogleFonts.cairo(),
                    hintText: 'اكتب سببًا واضحًا ليظهر في سجل التعديلات',
                    hintStyle: GoogleFonts.cairo(fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (reasonText.trim().isEmpty) return;
                Navigator.pop(ctx, reasonText.trim());
              },
              icon: const Icon(Icons.save_rounded),
              label: Text('تأكيد وحفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<bool> _askMirrorSync(Map<String, dynamic> mirror) async {
    final ref =
        mirror['ReferenceNumber'] ?? '#${mirror['TransactionID'] ?? ''}';
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('مزامنة فاتورة الشراء المرآة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              content: Text(
                'تغيّرت أصناف العميل. هل تريد مزامنة فاتورة الشراء المرآة $ref الآن؟\n'
                'يمكنك اختيار «لاحقًا» للحفاظ على استقلال الفاتورتين.',
                style: GoogleFonts.cairo(height: 1.6),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('لاحقًا', style: GoogleFonts.cairo()),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.sync_rounded),
                  label: Text('مزامنة الآن', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (isEdit && (_invoiceStatus == 'Cancelled' || _invoiceStatus == 'Paid')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يمكن تعديل فاتورة ملغية أو مسددة بالكامل')),
      );
      return;
    }
    if (isEdit && !_canLimitedEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية تعديل هذه الفاتورة')),
      );
      return;
    }
    if (_selectedParty == null && !isPurchase) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اختر العميل أولاً', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اختر المخزن', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('يجب وجود صنف واحد على الأقل', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    if (_items.any((e) => e.quantity <= 0 || e.unitPrice < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('راجع الكميات والأسعار قبل الحفظ')),
      );
      return;
    }
    if (isEdit && _grandTotal < _originalPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الإجمالي الجديد لا يمكن أن يقل عن المدفوع (${NumberFormat('#,##0.00').format(_originalPaid)} ج)',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final advanceTotal = _advanceTotal;
    if (!isEdit && _paidAmount + advanceTotal > _grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('إجمالي المدفوع أكبر من الإجمالي', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    String? fullEditReason;
    if (_canFullEdit) {
      fullEditReason = await _askFullEditReason();
      if (fullEditReason == null) return;
    }

    setState(() => _saving = true);
    try {
      Map<String, dynamic> result;
      int? targetId = widget.invoiceId;
      Map<String, dynamic>? mirrorSync;

      if (isEdit && _canFullEdit) {
        result = await InvoiceService.instance.fullEdit(
          widget.invoiceId!,
          {
            'transactionDate': _transactionDate.toIso8601String(),
            'warehouseId': _selectedWarehouseId,
            'dueDate': _dueDate?.toIso8601String(),
            'paymentMethod': _paymentMethod,
            'notes': _notesCtrl.text.trim(),
            'discountEntryMode': 'percent',
            'discountPercentage': double.tryParse(_discountPctCtrl.text) ?? 0,
            'items': _items
                .map((it) => {
                      'detailId': it.detailId,
                      'productId': it.productId,
                      'quantity': it.quantity,
                      'unitPrice': it.unitPrice,
                      'pricingTier': it.pricingTier,
                      'selectedAlternativeId': it.selectedAlternativeId,
                      'notes': '',
                    })
                .toList(),
            'newCharges': _charges
                .where((ch) => ch.isNew)
                .map((ch) => {
                      'chargeType': ch.chargeType,
                      'chargeDescription': ch.description,
                      'chargeAmount': ch.amount,
                    })
                .toList(),
            'fullEditReason': fullEditReason,
          },
        );
        final payload = result['data'];
        if (payload is Map && payload['mirrorSyncNeeded'] is Map) {
          mirrorSync = Map<String, dynamic>.from(
            payload['mirrorSyncNeeded'] as Map,
          );
        }
      } else if (isEdit) {
        await InvoiceService.instance.limitedEdit(
          widget.invoiceId!,
          {
            'notes': _notesCtrl.text.trim(),
            'dueDate': _dueDate?.toIso8601String(),
            'paymentMethod': _paymentMethod,
          },
        );
        result = {'success': true, 'message': 'تم حفظ التعديلات'};
      } else {
        result = await InvoiceService.instance.create({
          'transactionDate': _transactionDate.toIso8601String(),
          'partyId': isPurchase
              ? 11
              : _safeInt(_selectedParty!['PartyID'] ??
                  _selectedParty!['PartyId'] ??
                  _selectedParty!['id']),
          'transactionType': _invoiceType,
          'warehouseId': _selectedWarehouseId,
          'empId': null,
          'totalAmount': _totalAmount,
          'discountPercentage': double.tryParse(_discountPctCtrl.text) ?? 0,
          'discountAmount': _discountAmount,
          'netTotalAmount': _netTotal,
          'totalChargesAmount': _chargesTotal,
          'grandTotal': _grandTotal,
          'paidAmount': _paidAmount,
          'paymentMethod': _paymentMethod,
          'notes': _notesCtrl.text.trim(),
          'details': _items
              .map((it) => {
                    'productId': it.productId,
                    'quantity': it.quantity,
                    'unitPrice': it.unitPrice,
                    'pricingTier': it.pricingTier,
                    'selectedAlternativeId': it.selectedAlternativeId,
                    'notes': '',
                  })
              .toList(),
          'charges': _charges
              .map((ch) => {
                    'description': ch.description,
                    'amount': ch.amount,
                    'chargeType': ch.chargeType,
                  })
              .toList(),
          'selectedAdvanceChargeIds': _selectedAdvanceIds.toList(),
        });
        targetId = _safeInt(result['transactionId'] ?? result['TransactionID']);
        if (targetId == 0) targetId = null;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'تم الحفظ بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mirrorSync != null) {
        final sync = await _askMirrorSync(mirrorSync);
        if (sync && mounted) {
          try {
            await InvoiceService.instance.syncMirror(
              _safeInt(
                  mirrorSync['TransactionID'] ?? mirrorSync['TransactionId']),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تمت مزامنة فاتورة الشراء المرآة بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } on ApiException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(e.message), backgroundColor: Colors.red),
              );
            }
          }
        }
      }

      if (!mounted) return;
      if (isEdit) {
        Navigator.pop(context, true);
        return;
      }
      targetId ??= widget.invoiceId;
      if (targetId != null && targetId > 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(
              transactionId: targetId!,
              username: widget.username,
              invoiceType: _invoiceType,
            ),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message, style: GoogleFonts.cairo()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===========================================================================
  // 🎨 الواجهة الرسومية الفخمة (Ultra-Modern POS / FinTech UI)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPurchase
                      ? Icons.local_mall_rounded
                      : Icons.point_of_sale_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit
                        ? (isPurchase
                            ? 'تعديل فاتورة شراء'
                            : 'تعديل فاتورة مبيعات')
                        : (isPurchase
                            ? 'فاتورة مشتريات جديدة'
                            : 'نقطة بيع • فاتورة جديدة'),
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    isEdit
                        ? 'رقم المرجع #${widget.invoiceId}'
                        : 'إصدار سريع ومباشر',
                    style: GoogleFonts.cairo(
                        fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                isPurchase ? 'مشتريات' : 'مبيعات',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _loading ? null : _buildStickyBottomBar(),
        body: Stack(
          children: [
            _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.gold))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                    children: [
                      _buildHeroDashboard(),
                      const SizedBox(height: 16),
                      _buildPartyModernCard(),
                      const SizedBox(height: 16),
                      _buildWarehouseAndRefBar(),
                      const SizedBox(height: 16),
                      _buildItemsModernSection(),
                      const SizedBox(height: 16),
                      _buildChargesModernSection(),
                      const SizedBox(height: 16),
                      _buildReceiptSummaryCard(),
                    ],
                  ),
            if (_saving)
              CrmDesignSystem.busyOverlay(text: 'جاري حفظ واعتماد الفاتورة...'),
          ],
        ),
      ),
    );
  }

  // 1️⃣ لوحة التحكم العلوية المدمجة (Hero Financial Dashboard)
  Widget _buildHeroDashboard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.navy,
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'صافي قيمة الفاتورة الحالية',
                    style: GoogleFonts.cairo(
                        fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,##0').format(_grandTotal),
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
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  children: [
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
                      'أصناف مضافة',
                      style: GoogleFonts.cairo(
                          fontSize: 10, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // كبسولات التواريخ التفاعلية
          Row(
            children: [
              Expanded(
                child: _buildDatePill(
                  icon: Icons.calendar_today_rounded,
                  label: 'تاريخ الفاتورة',
                  value: DateFormat('yyyy/MM/dd').format(_transactionDate),
                  onTap: (isEdit && !_canFullEdit)
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDate: _transactionDate,
                          );
                          if (d != null) setState(() => _transactionDate = d);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDatePill(
                  icon: Icons.local_shipping_outlined,
                  label: 'موعد التسليم',
                  value: _dueDate == null
                      ? 'حدد الموعد'
                      : DateFormat('yyyy/MM/dd').format(_dueDate!),
                  isHighlighted: _dueDate != null,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _dueDate ?? DateTime.now(),
                    );
                    if (d != null) setState(() => _dueDate = d);
                  },
                ),
              ),
            ],
          ),
          if (isEdit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _canFullEdit
                          ? 'وضع التعديل الكامل مفعّل: يمكنك تعديل الأصناف والأسعار والمخزن'
                          : 'وضع التعديل المحدود: مسموح بتعديل الملاحظات والتسليم والدفع فقط',
                      style: GoogleFonts.cairo(
                          fontSize: 10.5, color: Colors.orange.shade100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePill({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.gold.withOpacity(0.18)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? AppColors.gold.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            const Icon(Icons.edit_calendar_rounded,
                size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // 2️⃣ كارت العميل الذكي (VIP Client Ticket)
  Widget _buildPartyModernCard() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    if (isPurchase) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.factory_rounded,
                  color: Colors.blue.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المورد المعتمد: المصنع الرئيسي (كود 11)',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 13.5)),
                  Text(
                      'فاتورة توريد مباشر لمعرض الشركة — تضاف للمخزون عند الاستلام',
                      style:
                          GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedParty == null)
            InkWell(
              onTap: isEdit ? null : _openPartySearchSheet,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gold.withOpacity(0.25),
                            AppColors.gold.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.navy, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تحديد العميل صاحب الفاتورة *',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'اضغط للبحث السريع بالاسم أو رقم الموبايل',
                            style: GoogleFonts.cairo(
                                fontSize: 11.5, color: Colors.grey),
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
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'اختيار',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _safeInitial(
                              _selectedParty!['PartyName']?.toString()),
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
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    (_selectedParty!['PartyName'] ?? '')
                                        .toString(),
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_rounded,
                                    color: Colors.green, size: 16),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '📞 ${(_selectedParty!['Phone'] ?? 'بدون رقم هاتف').toString()}',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isEdit)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor:
                                AppColors.gold.withOpacity(0.15),
                            foregroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _openPartySearchSheet,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: Text('تغيير',
                              style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (_advances.isNotEmpty && !isEdit) ...[
                    const Divider(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '💳 دفعات مقدمة متاحة للعميل (اضغط لخصمها من الفاتورة):',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _advances.map((adv) {
                        final id =
                            _safeInt(adv['ChargeId'] ?? adv['ChargeID']);
                        final amount = _safeDouble(adv['ChargeAmount']);
                        final desc =
                            (adv['ChargeDescription'] ?? 'دفعة مقدمة')
                                .toString();
                        final selected = _selectedAdvanceIds.contains(id);

                        return FilterChip(
                          selected: selected,
                          selectedColor: Colors.teal.withOpacity(0.18),
                          checkmarkColor: Colors.teal.shade800,
                          label: Text(
                            '${NumberFormat('#,###').format(amount)} ج • $desc',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Colors.teal.shade900
                                  : AppColors.text(_isDark),
                            ),
                          ),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedAdvanceIds.add(id);
                              } else {
                                _selectedAdvanceIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 3️⃣ شريط المخزن ورقم الفاتورة (Warehouse & Reference Compact Bar)
  Widget _buildWarehouseAndRefBar() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int?>(
              value: _selectedWarehouseId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'المخزن المعني بالصرف/الاستلام *',
                labelStyle: GoogleFonts.cairo(
                    fontSize: 11.5, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.warehouse_rounded,
                    size: 18, color: AppColors.gold),
                filled: true,
                fillColor: _isDark
                    ? Colors.white.withOpacity(0.03)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('اختر المخزن...',
                      style: GoogleFonts.cairo(fontSize: 12)),
                ),
                ..._warehouses.map((w) => DropdownMenuItem<int?>(
                      value: _safeInt(w['WarehouseID'] ?? w['WarehouseId']),
                      child: Text((w['WarehouseName'] ?? '').toString(),
                          style: GoogleFonts.cairo(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    )),
              ],
              onChanged: (isEdit && !_canFullEdit)
                  ? null
                  : (v) => setState(() => _selectedWarehouseId = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _refCtrl,
              readOnly: isEdit,
              style:
                  GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'رقم الفاتورة',
                labelStyle: GoogleFonts.cairo(fontSize: 11),
                hintText: 'تلقائي',
                hintStyle: GoogleFonts.cairo(fontSize: 10.5),
                prefixIcon:
                    const Icon(Icons.tag_rounded, size: 17, color: Colors.grey),
                filled: true,
                fillColor: _isDark
                    ? Colors.white.withOpacity(0.03)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4️⃣ قسم الأصناف الحديث (Bento Line-Item Cards)
  Widget _buildItemsModernSection() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_bag_rounded,
                    color: AppColors.navy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بنود وأصناف الفاتورة',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    Text(
                      _items.isEmpty
                          ? 'لم يتم إدراج أصناف بعد'
                          : 'إجمالي ${_items.length} صنف بقيمة ${NumberFormat('#,###').format(_totalAmount)} ج',
                      style:
                          GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (!isEdit || _canFullEdit)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _openProductSearchSheet,
                  icon: Icon(Icons.add_circle_outline_rounded,
                      size: 17, color: AppColors.gold),
                  label: Text(
                    'إضافة أصناف',
                    style: GoogleFonts.cairo(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            InkWell(
              onTap: (!isEdit || _canFullEdit) ? _openProductSearchSheet : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: _isDark
                      ? Colors.white.withOpacity(0.02)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withOpacity(0.35),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_shopping_cart_rounded,
                        size: 42, color: AppColors.gold),
                    const SizedBox(height: 10),
                    Text(
                      'اضغط هنا لفتح كتالوج المنتجات وإضافة الأصناف',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'يمكنك البحث بالاسم واختيار أكثر من صنف دفعة واحدة',
                      style:
                          GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
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
              itemBuilder: (_, idx) => _buildBentoItemCard(_items[idx], idx),
            ),
        ],
      ),
    );
  }

  Widget _buildBentoItemCard(_InvoiceItem it, int idx) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withOpacity(0.03)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الهيدر: رقم البند + اسم الصنف + زر الحذف
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  children: [
                    Text(
                      it.productName,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: it.isShowroom
                                ? Colors.teal.withOpacity(0.12)
                                : Colors.indigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            it.isShowroom
                                ? 'معرض • متاح بالمخزن: ${it.availableStock}'
                                : 'طلبية مخصصة للعميل',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: it.isShowroom
                                  ? Colors.teal.shade700
                                  : Colors.indigo.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isEdit || _canFullEdit)
                InkWell(
                  onTap: () => setState(() {
                    it.dispose();
                    _items.removeAt(idx);
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // شريط الفئة السعرية (Segmented Tier Selector)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _isDark
                  ? Colors.black.withOpacity(0.25)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentTierButton(it, 'CClass', 'ستاندرد'),
                _buildSegmentTierButton(it, 'Premium', 'بريميوم ⭐'),
                _buildSegmentTierButton(it, 'Elite', 'إيليت 👑'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // الكمية + السعر + الإجمالي
          Row(
            children: [
              // كبسولة الكمية
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepBtn(
                      icon: Icons.remove_rounded,
                      onTap: it.isEditMode
                          ? null
                          : () {
                              if (it.quantity > 1) {
                                it.qtyCtrl.text =
                                    (it.quantity - 1).toStringAsFixed(0);
                              }
                            },
                    ),
                    SizedBox(
                      width: 40,
                      child: TextField(
                        controller: it.qtyCtrl,
                        readOnly: it.isEditMode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(
                            fontSize: 13.5, fontWeight: FontWeight.w900),
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
                      onTap: it.isEditMode
                          ? null
                          : () {
                              it.qtyCtrl.text =
                                  (it.quantity + 1).toStringAsFixed(0);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // سعر الوحدة
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سعر الوحدة (ج.م)',
                          style: GoogleFonts.cairo(
                              fontSize: 9.5, color: Colors.grey)),
                      TextField(
                        controller: it.priceCtrl,
                        readOnly: it.isEditMode,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(
                            fontSize: 13, fontWeight: FontWeight.w900),
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
              // إجمالي الصنف
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الإجمالي',
                        style: GoogleFonts.cairo(
                            fontSize: 9.5, color: Colors.grey.shade600)),
                    Text(
                      '${NumberFormat('#,###').format(it.total)} ج',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: _isDark ? AppColors.gold : AppColors.navy,
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

  Widget _buildSegmentTierButton(_InvoiceItem it, String tierKey, String label) {
    final selected = it.pricingTier == tierKey;
    return Expanded(
      child: GestureDetector(
        onTap: it.isEditMode
            ? null
            : () => setState(() => it.pricingTier = tierKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.navy.withOpacity(0.2),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected
                  ? Colors.white
                  : (_isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBtn({
    required IconData icon,
    VoidCallback? onTap,
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
              ? AppColors.gold.withOpacity(0.2)
              : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isPlus ? AppColors.navy : Colors.grey.shade700,
        ),
      ),
    );
  }

  // 5️⃣ قسم الرسوم الإضافية والملاحظات
  Widget _buildChargesModernSection() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  color: Colors.deepPurple.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مصاريف الشحن والتركيب والملاحظات',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
              if (!isEdit || _canFullEdit)
                TextButton.icon(
                  onPressed: () => setState(() => _charges.add(_ChargeItem(
                        chargeType: 'Shipping',
                        description: 'مصاريف شحن وتوصيل',
                        amount: 0,
                        onChanged: _onTotalsChanged,
                        isEditMode: false,
                        isNew: true,
                      ))),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('إضافة رسم',
                      style: GoogleFonts.cairo(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (_charges.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._charges.asMap().entries.map((entry) {
              final idx = entry.key;
              final ch = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isDark
                      ? Colors.white.withOpacity(0.03)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: ch.descCtrl,
                        readOnly: ch.isEditMode,
                        style: GoogleFonts.cairo(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'بيان الرسم (شحن/تركيب)...',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ch.amountCtrl,
                        readOnly: ch.isEditMode,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'القيمة',
                          suffixText: 'ج',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ),
                    if (!isEdit || ch.isNew)
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.red),
                        onPressed: () => setState(() {
                          ch.dispose();
                          _charges.removeAt(idx);
                        }),
                      ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: GoogleFonts.cairo(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'اكتب أي ملاحظات إضافية أو شروط تسليم خاصة بالفاتورة...',
              hintStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              filled: true,
              fillColor: _isDark
                  ? Colors.white.withOpacity(0.03)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6️⃣ كارت ملخص الفاتورة والدفع (Modern Financial Receipt)
  Widget _buildReceiptSummaryCard() {
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                'الحساب الختامي وطريقة السداد',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _receiptRow(
              'إجمالي قيمة الأصناف', '${NumberFormat('#,###').format(_totalAmount)} ج'),
          const SizedBox(height: 10),
          // سطر الخصم التفاعلي
          Row(
            children: [
              Expanded(
                child: Text(
                  'نسبة الخصم الممنوحة (%)',
                  style: GoogleFonts.cairo(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 95,
                child: TextField(
                  controller: _discountPctCtrl,
                  readOnly: isEdit && !_canFullEdit,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.cairo(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    suffixText: '%',
                    isDense: true,
                    filled: true,
                    fillColor: _isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (_discountAmount > 0) ...[
            const SizedBox(height: 6),
            _receiptRow(
              'قيمة الخصم المخصومة',
              '- ${NumberFormat('#,###').format(_discountAmount)} ج',
              valueColor: Colors.red.shade600,
            ),
          ],
          if (_chargesTotal > 0) ...[
            const SizedBox(height: 6),
            _receiptRow(
              'إجمالي الرسوم الإضافية',
              '+ ${NumberFormat('#,###').format(_chargesTotal)} ج',
              valueColor: Colors.deepPurple,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          // الصافي النهائي البارز
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي النهائي المطلوب',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${NumberFormat('#,###').format(_grandTotal)} ج.م',
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // اختيار وسيلة الدفع بشكل مرئي عصري
          Text(
            'وسيلة الدفع المعتمدة:',
            style:
                GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentMethodCard('Cash', 'نقدي (كاش)', Icons.payments_rounded),
              const SizedBox(width: 8),
              _buildPaymentMethodCard(
                  'Bank', 'تحويل بنكي', Icons.account_balance_rounded),
              const SizedBox(width: 8),
              _buildPaymentMethodCard(
                  'Visa', 'بطاقة فيزا', Icons.credit_card_rounded),
            ],
          ),
          const SizedBox(height: 14),
          if (!isEdit) ...[
            TextField(
              controller: _paidCtrl,
              keyboardType: TextInputType.number,
              style:
                  GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'المبلغ المدفوع الآن عند الإصدار',
                labelStyle: GoogleFonts.cairo(fontSize: 12),
                prefixIcon:
                    Icon(Icons.attach_money_rounded, color: Colors.green.shade700),
                suffixIcon: TextButton(
                  onPressed: () {
                    final full =
                        (_grandTotal - _advanceTotal).clamp(0, double.infinity);
                    _paidCtrl.text = full.toStringAsFixed(0);
                  },
                  child: Text(
                    'سداد بالكامل',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  ),
                ),
                filled: true,
                fillColor: Colors.green.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.3)),
                ),
              ),
            ),
          ] else ...[
            _receiptRow(
              'إجمالي المدفوع سابقاً',
              '${NumberFormat('#,###').format(_originalPaid)} ج',
              valueColor: Colors.green.shade700,
            ),
          ],
          if (_advanceTotal > 0) ...[
            const SizedBox(height: 8),
            _receiptRow(
              'دفعات مقدمة مخصومة',
              '${NumberFormat('#,###').format(_advanceTotal)} ج',
              valueColor: Colors.teal,
            ),
          ],
          const SizedBox(height: 14),
          // شريط المتبقي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _remaining > 0
                  ? Colors.red.withOpacity(0.08)
                  : Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _remaining > 0
                    ? Colors.red.withOpacity(0.25)
                    : Colors.green.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _remaining > 0 ? 'المتبقي (آجل على العميل):' : 'حالة الفاتورة:',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: _remaining > 0
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
                Text(
                  _remaining > 0
                      ? '${NumberFormat('#,###').format(_remaining)} ج.م'
                      : 'مسددة بالكامل ✓',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _remaining > 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(String key, String title, IconData icon) {
    final selected = _paymentMethod == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = key),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.navy
                : (_isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.grey.withOpacity(0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.gold : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? Colors.white
                      : (_isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12.5, color: AppColors.textSecondary(_isDark))),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.text(_isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإجمالي (${_items.length} أصناف)',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(_grandTotal)} ج.م',
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
                    : Icon(Icons.check_circle_rounded, color: AppColors.gold),
                label: Text(
                  _saving
                      ? 'جاري الحفظ...'
                      : (isEdit ? 'حفظ التعديلات' : 'اعتماد وحفظ الفاتورة'),
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
}

// =============================================================================
// 🛡️ StatefulWidget مستقل للبحث عن العميل (يمنع الشاشة الحمراء نهائياً)
// =============================================================================
class _PartySearchSheetWidget extends StatefulWidget {
  final bool isDark;
  final Future<List<dynamic>> Function(String) onSearch;

  const _PartySearchSheetWidget({
    required this.isDark,
    required this.onSearch,
  });

  @override
  State<_PartySearchSheetWidget> createState() =>
      _PartySearchSheetWidgetState();
}

class _PartySearchSheetWidgetState extends State<_PartySearchSheetWidget> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await widget.onSearch(q);
      if (mounted) {
        setState(() {
          _results = list;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded,
                      color: AppColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'البحث السريع عن عميل',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: GoogleFonts.cairo(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'اكتب اسم العميل أو رقم الهاتف...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.gold),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _searching
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _ctrl.text.trim().length < 2
                                ? 'اكتب حرفين على الأقل للبحث عن العميل'
                                : 'لا يوجد عميل مطابق لبحثك',
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final raw = _results[i];
                            if (raw is! Map) return const SizedBox.shrink();
                            final p = Map<String, dynamic>.from(raw);
                            final name = (p['PartyName'] ?? 'عميل').toString();
                            final phone = (p['Phone'] ?? '').toString();
                            final advBal =
                                _AddInvoiceScreenState._safeDouble(
                                    p['AdvanceBalance']);

                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: Colors.grey.withOpacity(0.2)),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.navy,
                                child: Text(
                                  _AddInvoiceScreenState._safeInitial(name),
                                  style: GoogleFonts.cairo(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              subtitle: Text(
                                phone.isEmpty ? 'بدون هاتف' : '📞 $phone',
                                style: GoogleFonts.cairo(fontSize: 11.5),
                              ),
                              trailing: advBal > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'مقدم: ${NumberFormat('#,###').format(advBal)} ج',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 14),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context, p);
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
// 🛡️ StatefulWidget مستقل لكتالوج المنتجات (يمنع الشاشة الحمراء نهائياً)
// =============================================================================
class _ProductSearchSheetWidget extends StatefulWidget {
  final bool isDark;
  final bool isPurchase;
  final List<dynamic> initialProducts;
  final bool Function(int) isProductAdded;
  final Future<List<dynamic>> Function(String) onSearch;
  final void Function(Map<String, dynamic>) onAddProduct;
  final int Function() addedCountGetter;

  const _ProductSearchSheetWidget({
    required this.isDark,
    required this.isPurchase,
    required this.initialProducts,
    required this.isProductAdded,
    required this.onSearch,
    required this.onAddProduct,
    required this.addedCountGetter,
  });

  @override
  State<_ProductSearchSheetWidget> createState() =>
      _ProductSearchSheetWidgetState();
}

class _ProductSearchSheetWidgetState extends State<_ProductSearchSheetWidget> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  late List<dynamic> _results;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _results = List.from(widget.initialProducts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await widget.onSearch(q);
      if (mounted) {
        setState(() {
          _results = list;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      color: AppColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'كتالوج الأصناف والمنتجات',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'تم (${widget.addedCountGetter()})',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: _results.isEmpty,
                style: GoogleFonts.cairo(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الصنف أو الكود...',
                  hintStyle:
                      GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.gold),
                  filled: true,
                  fillColor: widget.isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _searching
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _ctrl.text.trim().length < 2
                                ? 'اكتب حرفين على الأقل للبحث عن الأصناف'
                                : 'لا توجد أصناف مطابقة',
                            style: GoogleFonts.cairo(
                                fontSize: 13, color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final raw = _results[i];
                            if (raw is! Map) return const SizedBox.shrink();
                            final prod = Map<String, dynamic>.from(raw);
                            final pid = _AddInvoiceScreenState._safeInt(
                                prod['ProductID'] ?? prod['ProductId']);
                            final added = widget.isProductAdded(pid);
                            final stock = _AddInvoiceScreenState._safeInt(
                                prod['StockQuantity'] ?? prod['QTY']);
                            final price = widget.isPurchase
                                ? _AddInvoiceScreenState._safeDouble(
                                    prod['PurchasePrice'])
                                : _AddInvoiceScreenState._safeDouble(
                                    prod['SuggestedSalePrice']);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: added
                                    ? Colors.green.withOpacity(0.07)
                                    : (widget.isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: added
                                      ? Colors.green
                                      : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (prod['ProductName'] ?? '').toString(),
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الرصيد المتاح: $stock • السعر: ${NumberFormat('#,###').format(price)} ج',
                                          style: GoogleFonts.cairo(
                                              fontSize: 11.5,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: added
                                          ? Colors.green
                                          : AppColors.navy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: added
                                        ? null
                                        : () {
                                            widget.onAddProduct(prod);
                                            setState(() {});
                                          },
                                    icon: Icon(
                                        added
                                            ? Icons.check_rounded
                                            : Icons.add_rounded,
                                        size: 16),
                                    label: Text(
                                      added ? 'مضاف' : 'إضافة',
                                      style: GoogleFonts.cairo(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
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

class _InvoiceItem {
  final int detailId;
  final int productId;
  final String productName;
  final String productDescription;
  double quantity;
  double unitPrice;
  String pricingTier;
  dynamic selectedAlternativeId;
  final int availableStock;
  final bool isShowroom;
  final VoidCallback onChanged;
  final bool isEditMode;

  late final TextEditingController qtyCtrl;
  late final TextEditingController priceCtrl;

  _InvoiceItem({
    this.detailId = 0,
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.quantity,
    required this.unitPrice,
    required this.pricingTier,
    this.selectedAlternativeId,
    this.availableStock = 0,
    this.isShowroom = true,
    required this.onChanged,
    this.isEditMode = false,
  }) {
    qtyCtrl = TextEditingController(text: quantity.toStringAsFixed(0));
    priceCtrl = TextEditingController(text: unitPrice.toStringAsFixed(2));
    qtyCtrl.addListener(_onQtyChanged);
    priceCtrl.addListener(_onPriceChanged);
  }

  void _onQtyChanged() {
    final v = double.tryParse(qtyCtrl.text) ?? quantity;
    if (v != quantity) {
      quantity = v;
      onChanged();
    }
  }

  void _onPriceChanged() {
    final v = double.tryParse(priceCtrl.text) ?? unitPrice;
    if (v != unitPrice) {
      unitPrice = v;
      onChanged();
    }
  }

  double get total => quantity * unitPrice;

  void dispose() {
    qtyCtrl.removeListener(_onQtyChanged);
    priceCtrl.removeListener(_onPriceChanged);
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ChargeItem {
  final int chargeId;
  String chargeType;
  String description;
  double amount;
  final VoidCallback onChanged;
  final bool isEditMode;
  final bool isNew;

  late final TextEditingController descCtrl;
  late final TextEditingController amountCtrl;

  _ChargeItem({
    this.chargeId = 0,
    this.chargeType = 'Other',
    required this.description,
    required this.amount,
    required this.onChanged,
    this.isEditMode = false,
    this.isNew = true,
  }) {
    descCtrl = TextEditingController(text: description);
    amountCtrl = TextEditingController(text: amount.toStringAsFixed(2));
    descCtrl.addListener(_onDescChanged);
    amountCtrl.addListener(_onAmountChanged);
  }

  void _onDescChanged() {
    description = descCtrl.text;
  }

  void _onAmountChanged() {
    final v = double.tryParse(amountCtrl.text) ?? amount;
    if (v != amount) {
      amount = v;
      onChanged();
    }
  }

  void dispose() {
    descCtrl.removeListener(_onDescChanged);
    amountCtrl.removeListener(_onAmountChanged);
    descCtrl.dispose();
    amountCtrl.dispose();
  }
}