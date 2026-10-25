import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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

/// إضافة فاتورة مبيعات/مشتريات - مطابق بلازور Sales/InvoiceForm.razor
/// Workflow: عميل + مخزن + أصناف (معرض + مخصصة) + خصم + رسوم + دفع + ملخص
/// تصميم بهوية فلاتر navy+gold
/// ✅ تم إصلاح حساب الإجماليات 100% - تحديث لحظي عند تعديل الكمية/السعر/الخصم/الرسوم
class AddInvoiceScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? invoiceId; // للتعديل
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
  String _invoiceType = 'Sale'; // Sale | Purchase

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

  // Items added - now with persistent controllers
  List<_InvoiceItem> _items = [];
  List<_ChargeItem> _charges = [];
  Set<int> _selectedAdvanceIds = {};

  bool get _isDark => ThemeService().isDarkMode;
  bool get isEdit => widget.invoiceId != null;
  bool get isPurchase => _invoiceType == 'Purchase';

  double get _totalAmount => _items.fold(0, (sum, it) => sum + it.total);
  double get _discountAmount {
    final pct = double.tryParse(_discountPctCtrl.text) ?? 0;
    if (pct > 0) return _totalAmount * (pct / 100);
    return 0;
  }
  double get _netTotal => _totalAmount - _discountAmount;
  double get _chargesTotal => _charges.fold(0, (sum, ch) => sum + ch.amount);
  double get _grandTotal => _netTotal + _chargesTotal;
  double get _advanceTotal => _advances
      .where((a) => _selectedAdvanceIds.contains(a['ChargeId'] ?? a['ChargeID']))
      .fold(0, (sum, a) => sum + ((a['ChargeAmount'] ?? 0).toDouble()));
  double get _paidAmount => double.tryParse(_paidCtrl.text) ?? 0;
  double get _remaining {
    if (isEdit) {
      // في وضع التعديل: المتبقي = الإجمالي النهائي الحالي - المدفوع الأصلي من قاعدة البيانات
      // لو المستخدم غيّر الخصم، الإجمالي يتغير والمتبقي يتحدث تلقائياً
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
      // حمّل الفروع والمخازن بشكل منفصل — حتى لو فشل أحدهم لا يوقف الباقي (زي بلازور)
      List<dynamic> branches = [];
      List<dynamic> warehouses = [];
      List<dynamic> cashBoxes = [];

      try { branches = await InventoryService.getBranches(); } catch (_) {}
      try { warehouses = await InventoryService.getAllWarehouses(); } catch (_) {}

      // الخزائن: جرّب /active أولاً (مطابق لبلازور activeOnly:true) ثم fallback لـ /cashbox
      try {
        http.Response res = await http.get(Uri.parse('$baseUrl/api/cashbox/active'));
        if (res.statusCode == 200) {
          cashBoxes = jsonDecode(res.body) as List;
        } else {
          // fallback: كل الخزائن ثم فلترة النشط محلياً
          final fallback = await http.get(Uri.parse('$baseUrl/api/cashbox'));
          if (fallback.statusCode == 200) {
            final all = jsonDecode(fallback.body) as List;
            cashBoxes = all.where((c) => c['IsActive'] == true || c['IsActive'] == 1 || c['IsActive'] == null).toList();
          }
        }
      } catch (_) {
        try {
          final fallback = await http.get(Uri.parse('$baseUrl/api/cashbox'));
          if (fallback.statusCode == 200) cashBoxes = jsonDecode(fallback.body) as List;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _warehouses = warehouses;
        _cashBoxes = cashBoxes;
        if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
          _selectedWarehouseId = _warehouses.first['WarehouseID'] ?? _warehouses.first['WarehouseId'];
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
      final data = await InvoiceService.instance.getEditModel(widget.invoiceId!);
      final header = Map<String, dynamic>.from(data['header'] as Map? ?? {});
      final details = (data['details'] as List?) ?? const [];
      final charges = (data['charges'] as List?) ?? const [];
      final capabilities = Map<String, dynamic>.from(
        data['capabilities'] as Map? ?? {},
      );
      if (!mounted) return;

      for (final it in _items) it.dispose();
      for (final ch in _charges) ch.dispose();

      setState(() {
        _serverCanFullEdit = capabilities['canFullEdit'] == true;
        _serverCanLimitedEdit = capabilities['canLimitedEdit'] == true;
        _invoiceStatus = header['InvoiceStatus']?.toString();
        _invoiceType = header['TransactionType']?.toString() ?? _invoiceType;
        _refCtrl.text = header['ReferenceNumber']?.toString() ?? '';
        _notesCtrl.text = header['Notes']?.toString() ?? '';
        _selectedWarehouseId = header['WarehouseID'] ?? header['WarehouseId'];
        _transactionDate = header['TransactionDate'] != null
            ? DateTime.tryParse(header['TransactionDate'].toString()) ?? DateTime.now()
            : DateTime.now();
        _dueDate = header['DueDate'] != null
            ? DateTime.tryParse(header['DueDate'].toString())
            : null;
        _paymentMethod = header['PaymentMethod']?.toString() ?? 'Cash';
        _discountPctCtrl.text = (header['DiscountPercentage'] ?? 0).toString();
        _originalPaid = (header['PaidAmount'] ?? 0).toDouble();
        _originalGrand = (header['GrandTotal'] ?? 0).toDouble();

        final partyId = header['PartyID'] ?? header['PartyId'];
        final partyName = header['PartyName'] ?? header['SupplierName'] ?? '';
        if (partyId != null) {
          _selectedParty = {
            'PartyID': partyId,
            'PartyName': partyName,
            'Phone': header['Phone'] ?? '',
          };
        }

        _items = details.map((raw) {
          final d = Map<String, dynamic>.from(raw as Map);
          return _InvoiceItem(
            detailId: d['DetailID'] ?? d['DetailId'] ?? 0,
            productId: d['ProductID'] ?? 0,
            productName: d['ProductName'] ?? '',
            productDescription:
                d['SpecificationSummary'] ?? d['ProductDescription'] ?? '',
            quantity: (d['Quantity'] ?? 1).toDouble(),
            unitPrice: (d['UnitPrice'] ?? 0).toDouble(),
            pricingTier: d['PricingTier'] ?? 'Premium',
            selectedAlternativeId:
                d['SelectedAlternativeID'] ?? d['SelectedAlternativeId'],
            availableStock: (d['AvailableStock'] ?? 0) is int
                ? d['AvailableStock'] ?? 0
                : int.tryParse('${d['AvailableStock'] ?? 0}') ?? 0,
            isShowroom: d['Customer'] == null,
            onChanged: _onTotalsChanged,
            isEditMode: !_canFullEdit,
          );
        }).toList();

        _charges = charges.map((raw) {
          final c = Map<String, dynamic>.from(raw as Map);
          return _ChargeItem(
            chargeId: c['ChargeID'] ?? c['ChargeId'] ?? 0,
            chargeType: c['ChargeType']?.toString() ?? 'Other',
            description: c['ChargeDescription'] ?? '',
            amount: (c['ChargeAmount'] ?? 0).toDouble(),
            onChanged: _onTotalsChanged,
            isEditMode: true, // الرسوم القديمة لا تتغير؛ تضاف رسوم جديدة فقط.
            isNew: false,
          );
        }).toList();
      });

      if ((_invoiceStatus == 'Cancelled' || _invoiceStatus == 'Paid') && mounted) {
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
          SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<List<dynamic>> _searchParties(String query) async {
    if (query.trim().length < 1) return [];
    try {
      // استخدم ApiClient الموحد (يضيف التوكن تلقائياً) وبراميتر q المطابق للبلازور والـ API
      final api = ApiClient.instance;
      final res = await api.get('/api/clients/search', query: {'q': query.trim()});
      if (res.statusCode == 200) {
        final body = api.decode(res);
        if (body is List) return body;
        if (body is Map && body['data'] is List) return body['data'] as List;
        return body as List;
      }
      // fallback: جرّب http المباشر لو ApiClient فشل
      final fallback = await http.get(Uri.parse('$baseUrl/api/clients/search?q=${Uri.encodeComponent(query)}'));
      if (fallback.statusCode == 200) return jsonDecode(fallback.body) as List;
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _searchProducts(String query) async {
    // للبيع: اسمح بالبحث حتى بدون عميل (منتجات المعرض موجودة دائماً — زي بلازور SearchShowroomProducts)
    // للمشتريات: لا يحتاج عميل أصلاً
    if (_selectedWarehouseId == null) return [];
    if (query.trim().length < 1) return [];
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
        return body as List;
      }
      // fallback http
      String url = '$baseUrl/api/products?search=${Uri.encodeComponent(query)}';
      if (_selectedWarehouseId != null) url += '&warehouseId=$_selectedWarehouseId';
      final fallback = await http.get(Uri.parse(url));
      if (fallback.statusCode == 200) return jsonDecode(fallback.body) as List;
    } catch (_) {}
    return [];
  }

  Future<void> _loadAdvances(int partyId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients/$partyId/advances?unappliedOnly=true'));
      if (res.statusCode == 200 && mounted) {
        setState(() => _advances = jsonDecode(res.body) as List);
      }
    } catch (_) {}
  }

  void _addProduct(Map<String, dynamic> prod) {
    final pid = prod['ProductID'] ?? prod['ProductId'] ?? 0;
    if (_items.any((it) => it.productId == pid)) return;

    String tier = 'Premium';
    double price = 0;
    final pType = '${prod['PricingType'] ?? ''}';
    if (pType.toLowerCase().contains('cclass') || pType.toLowerCase().contains('standard')) {
      tier = 'CClass';
      price = isPurchase
          ? (prod['PurchasePriceCClass'] ?? prod['PurchasePrice'] ?? 0).toDouble()
          : (prod['SuggestedSalePriceCClass'] ?? prod['SuggestedSalePrice'] ?? 0).toDouble();
    } else if (pType.toLowerCase().contains('elite')) {
      tier = 'Elite';
      price = isPurchase
          ? (prod['PurchasePriceElite'] ?? prod['PurchasePrice'] ?? 0).toDouble()
          : (prod['SuggestedSalePriceElite'] ?? prod['SuggestedSalePrice'] ?? 0).toDouble();
    } else {
      tier = 'Premium';
      price = isPurchase ? (prod['PurchasePrice'] ?? 0).toDouble() : (prod['SuggestedSalePrice'] ?? 0).toDouble();
    }

    setState(() {
      _items.add(_InvoiceItem(
        productId: pid is int ? pid : int.tryParse('$pid') ?? 0,
        productName: prod['ProductName'] ?? '',
        productDescription: prod['ProductDescription'] ?? '',
        quantity: 1,
        unitPrice: price,
        pricingTier: tier,
        availableStock: prod['StockQuantity'] ?? prod['QTY'] ?? 0,
        isShowroom: prod['Customer'] == null,
        onChanged: _onTotalsChanged,
        isEditMode: false,
      ));
    });
    _calcDueDate();
  }

  void _calcDueDate() {
    int maxPeriod = 0;
    for (final it in _items) {
      // نحتاج Period من المنتج - نفترض من API أو 0
    }
    if (maxPeriod > 0) {
      setState(() => _dueDate = _transactionDate.add(Duration(days: maxPeriod)));
    }
  }

  Future<String?> _askFullEditReason() async {
    final controller = TextEditingController();
    final newItems = _items.where((e) => e.detailId == 0).length;
    final newCharges = _charges.where((e) => e.isNew).length;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'سبب التعديل *',
                  hintText: 'اكتب سببًا واضحًا ليظهر في سجل التعديلات',
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
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx, value);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('تأكيد وحفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _askMirrorSync(Map<String, dynamic> mirror) async {
    final ref = mirror['ReferenceNumber'] ?? '#${mirror['TransactionID'] ?? ''}';
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('مزامنة فاتورة الشراء المرآة'),
            content: Text(
              'تغيّرت أصناف العميل. هل تريد مزامنة فاتورة الشراء المرآة $ref الآن؟\n'
              'يمكنك اختيار «لاحقًا» للحفاظ على استقلال الفاتورتين.',
              style: GoogleFonts.cairo(height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('لاحقًا'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('مزامنة الآن'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (isEdit && (_invoiceStatus == 'Cancelled' || _invoiceStatus == 'Paid')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تعديل فاتورة ملغية أو مسددة بالكامل')),
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
          content: Text('يجب وجود صنف واحد على الأقل', style: GoogleFonts.cairo()),
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
          content: Text('إجمالي المدفوع أكبر من الإجمالي', style: GoogleFonts.cairo()),
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
              : (_selectedParty!['PartyID'] ??
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
        targetId = result['transactionId'] ?? result['TransactionID'];
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
              mirrorSync['TransactionID'] ?? mirrorSync['TransactionId'],
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
                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
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
      if (targetId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(
              transactionId: targetId is int
                  ? targetId
                  : int.tryParse('$targetId') ?? 0,
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(
              isEdit
                  ? (isPurchase ? 'تعديل فاتورة شراء' : 'تعديل فاتورة مبيعات')
                  : (isPurchase ? 'فاتورة مشتريات جديدة' : 'فاتورة مبيعات جديدة'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          actions: [
            if (_saving)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            else
              IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save)
          ],
        ),
        body: Stack(children: [
          _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : Form(
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  CrmDesignSystem.sectionCard(
                      title: 'بيانات الفاتورة', icon: Icons.description_rounded, color: AppColors.navy, child: _buildInvoiceInfo()),
                  const SizedBox(height: 12),
                  CrmDesignSystem.sectionCard(
                      title: isPurchase ? 'المورد' : 'العميل',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF3B82F6),
                      child: _buildPartySection()),
                  const SizedBox(height: 12),
                  CrmDesignSystem.sectionCard(
                      title: 'الأصناف (${_items.length})',
                      icon: Icons.inventory_2_rounded,
                      color: AppColors.gold,
                      child: _buildItemsSection()),
                  const SizedBox(height: 12),
                  CrmDesignSystem.sectionCard(
                      title: 'رسوم إضافية (${_charges.length})',
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF8B5CF6),
                      trailing: (!isEdit || _canFullEdit)
                          ? TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('إضافة رسم', style: GoogleFonts.cairo(fontSize: 11)),
                              onPressed: () => setState(() => _charges.add(_ChargeItem(
                                    chargeType: 'Other',
                                    description: '',
                                    amount: 0,
                                    onChanged: _onTotalsChanged,
                                    isEditMode: false,
                                    isNew: true,
                                  ))))
                          : null,
                      child: _buildChargesSection()),
                  const SizedBox(height: 12),
                  CrmDesignSystem.sectionCard(
                      title: 'ملاحظات',
                      icon: Icons.notes_rounded,
                      color: Colors.grey,
                      child: TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          style: GoogleFonts.cairo(fontSize: 12),
                          decoration: InputDecoration(
                              hintText: 'ملاحظات على الفاتورة...',
                              hintStyle: GoogleFonts.cairo(fontSize: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(height: 12),
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'جاري الحفظ...' : (isEdit ? 'حفظ التعديلات' : 'حفظ الفاتورة'),
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)))),
                ])),
          if (_saving) CrmDesignSystem.busyOverlay(text: 'جاري حفظ الفاتورة...'),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.gold, AppColors.gold.withOpacity(0.75)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(12)),
            child: Icon(isPurchase ? Icons.shopping_cart_rounded : Icons.receipt_long_rounded, color: AppColors.navy, size: 24)),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              isEdit
                  ? (isPurchase ? 'تعديل فاتورة شراء' : 'تعديل فاتورة مبيعات')
                  : (isPurchase ? 'فاتورة مشتريات جديدة' : 'فاتورة مبيعات جديدة'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.navy)),
          Text(
              isEdit
                  ? (_canFullEdit
                      ? 'تعديل كامل موثق مع إعادة حساب الإجماليات والمخزون'
                      : 'تعديل محدود للبيانات التشغيلية')
                  : (isPurchase ? 'إنشاء فاتورة شراء للمعرض — يدخل المخزون عند الاستلام الفعلي' : 'يمكن إضافة منتجات العميل + منتجات المعرض من المخزن في نفس الفاتورة'),
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.navy.withOpacity(0.75))),
        ])),
        const SizedBox(width: 8),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
            child: Text(_invoiceType == 'Sale' ? 'مبيعات' : 'مشتريات',
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy))),
      ]),
    );
  }

  Widget _buildInvoiceInfo() {
    return Column(children: [
      Row(children: [
        Expanded(
            child: TextField(
                controller: _refCtrl,
                readOnly: isEdit,
                style: GoogleFonts.cairo(fontSize: 12),
                decoration: InputDecoration(
                    labelText: 'رقم الفاتورة',
                    labelStyle: GoogleFonts.cairo(fontSize: 11),
                    hintText: 'اتركه فاضي للتوليد التلقائي',
                    hintStyle: GoogleFonts.cairo(fontSize: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
        const SizedBox(width: 8),
        Expanded(
            child: InkWell(
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
                child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10), color: (isEdit && !_canFullEdit) ? Colors.grey.shade100 : null),
                    child: Row(children: [
                      Icon(Icons.event_rounded, size: 16, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(DateFormat('yyyy/MM/dd').format(_transactionDate), style: GoogleFonts.cairo(fontSize: 12))
                    ])))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<int?>(
                value: _selectedWarehouseId,
                decoration: InputDecoration(
                    labelText: 'المخزن *', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text('اختر المخزن', style: GoogleFonts.cairo(fontSize: 12))),
                  ..._warehouses.map((w) => DropdownMenuItem<int?>(
                      value: w['WarehouseID'] ?? w['WarehouseId'],
                      child: Text(w['WarehouseName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))
                ],
                onChanged: (isEdit && !_canFullEdit)
                    ? null
                    : (v) => setState(() => _selectedWarehouseId = v))),
        const SizedBox(width: 8),
        Expanded(
            child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _dueDate ?? DateTime.now());
                  if (d != null) setState(() => _dueDate = d);
                },
                child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.local_shipping_rounded, size: 16, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(_dueDate == null ? 'تاريخ التسليم' : DateFormat('yyyy/MM/dd').format(_dueDate!), style: GoogleFonts.cairo(fontSize: 12))
                    ])))),
      ]),
      if (isEdit) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.2))),
          child: Row(children: [
            Icon(Icons.info_rounded, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    _canFullEdit
                        ? 'تعديل كامل: يمكنك إضافة أو حذف أو استبدال الأصناف وتغيير المخزن والأسعار، وسيُراجع المخزون عند الحفظ.'
                        : 'تعديل محدود: الملاحظات وتاريخ التسليم وطريقة الدفع فقط.',
                    style: GoogleFonts.cairo(fontSize: 10, color: Colors.orange.shade800))),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildPartySection() {
    if (isPurchase) {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.20))),
          child: Row(children: [
            Icon(Icons.factory_rounded, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('المورد ثابت: المصنع - كود 11 - هذه الشاشة مخصصة لشراء منتجات المعرض من المصنع فقط',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w600)))
          ]));
    }

    return Column(children: [
      if (!isEdit)
        TextField(
          controller: _searchPartyCtrl,
          style: GoogleFonts.cairo(fontSize: 12),
          decoration: InputDecoration(
              labelText: 'ابحث عن العميل بالاسم أو الهاتف *',
              labelStyle: GoogleFonts.cairo(fontSize: 11),
              hintText: 'اكتب للبحث...',
              hintStyle: GoogleFonts.cairo(fontSize: 11),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _selectedParty != null
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        setState(() => _selectedParty = null);
                        _searchPartyCtrl.clear();
                      })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (v) async {
            if (v.trim().length < 2) return;
            final list = await _searchParties(v);
            if (list.isNotEmpty && mounted) {
              final picked = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  backgroundColor: AppColors.card(_isDark),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => SafeArea(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(height: 10),
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 12),
                        Text('اختر العميل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        SizedBox(
                            height: 300,
                            child: ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (_, i) => ListTile(
                                      title: Text(list[i]['PartyName'] ?? '', style: GoogleFonts.cairo(fontSize: 13)),
                                      subtitle: Text('📞 ${list[i]['Phone'] ?? ''} • رصيد ${list[i]['AdvanceBalance'] ?? 0}',
                                          style: GoogleFonts.cairo(fontSize: 11)),
                                      onTap: () => Navigator.pop(ctx, Map<String, dynamic>.from(list[i] as Map)),
                                    )))
                      ])));
              if (picked != null) {
                setState(() => _selectedParty = picked);
                _loadAdvances(picked['PartyID'] ?? picked['PartyId'] ?? picked['id'] ?? 0);
              }
            }
          },
        ),
      if (_selectedParty != null) ...[
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.20))),
            child: Row(children: [
              Icon(Icons.person_rounded, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedParty!['PartyName'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('📞 ${_selectedParty!['Phone'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600))
              ]))
            ])),
      ],
      if (_advances.isNotEmpty && !isEdit) ...[
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('هذا العميل لديه دفعات مقدمة: ${_advances.length} - اختر ما تريد خصمه',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
              const SizedBox(height: 6),
              ..._advances.map((adv) {
                final id = adv['ChargeId'] ?? adv['ChargeID'] ?? 0;
                final sel = _selectedAdvanceIds.contains(id);
                return CheckboxListTile(
                    value: sel,
                    title: Text('${adv['ChargeAmount']} ج - ${adv['ChargeDescription']}', style: GoogleFonts.cairo(fontSize: 11)),
                    dense: true,
                    onChanged: (v) {
                      setState(() {
                        if (v == true)
                          _selectedAdvanceIds.add(id is int ? id : int.tryParse('$id') ?? 0);
                        else
                          _selectedAdvanceIds.remove(id);
                      });
                    });
              }),
            ])),
      ],
    ]);
  }

  Widget _buildItemsSection() {
    return Column(children: [
      if (!isEdit || _canFullEdit) ...[
        TextField(
          controller: _searchProductCtrl,
          style: GoogleFonts.cairo(fontSize: 12),
          decoration: InputDecoration(
              labelText: 'ابحث عن منتج لإضافته',
              labelStyle: GoogleFonts.cairo(fontSize: 11),
              hintText: _selectedWarehouseId == null ? 'اختر المخزن أولاً' : 'ابحث باسم المنتج...',
              hintStyle: GoogleFonts.cairo(fontSize: 11),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (v) async {
            if (v.trim().length < 2) return;
            final list = await _searchProducts(v);
            if (list.isNotEmpty && mounted) {
              setState(() => _availableProducts = list);
            }
          },
        ),
        if (_availableProducts.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _availableProducts.length,
              itemBuilder: (_, i) {
                final prod = _availableProducts[i];
                final added = _items.any((it) => it.productId == (prod['ProductID'] ?? prod['ProductId'] ?? 0));
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: added ? Colors.green.withOpacity(0.10) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: added ? Colors.green.withOpacity(0.25) : Colors.black.withOpacity(0.06))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                          child: Text(prod['ProductName'] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold))),
                      if (added) const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green)
                    ]),
                    const SizedBox(height: 4),
                    Text('${prod['GroupName'] ?? ''} • ${prod['StockQuantity'] ?? 0} رصيد',
                        style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey.shade600)),
                    const Spacer(),
                    SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: added ? Colors.green : AppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero),
                            onPressed: added ? null : () => _addProduct(Map<String, dynamic>.from(prod as Map)),
                            child: Text(added ? 'تمت الإضافة' : 'إضافة', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)))),
                  ]),
                );
              },
            ),
          ),
        ],
      ],
      if (_items.isEmpty) ...[
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Column(children: [
              Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 6),
              Text(_selectedParty == null && !isPurchase ? 'اختر العميل أولاً لعرض المنتجات' : 'لا توجد أصناف مضافة بعد',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600))
            ]))),
      ] else ...[
        const SizedBox(height: 12),
        Column(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(flex: 3, child: Text('الصنف', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text('باقة', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text('كمية', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text('سعر', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text('إجمالي', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
              ])),
          const SizedBox(height: 6),
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final it = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.06))),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.productName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                      if (it.isShowroom)
                        Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text('من المخزون • رصيد ${it.availableStock}',
                                style: GoogleFonts.cairo(fontSize: 9, color: Colors.green.shade700)))
                      else
                        Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
                            child: Text('مخصص للعميل', style: GoogleFonts.cairo(fontSize: 9, color: Colors.blue.shade700)))
                    ])),
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: it.pricingTier,
                            isDense: true,
                            isExpanded: true,
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'CClass', child: Text('ستاندرد')),
                              DropdownMenuItem(value: 'Premium', child: Text('بريميوم')),
                              DropdownMenuItem(value: 'Elite', child: Text('إيليت')),
                            ],
                            onChanged: it.isEditMode
                                ? null
                                : (value) => setState(() {
                                      it.pricingTier = value ?? it.pricingTier;
                                    }),
                          ),
                        ))),
                Expanded(
                  child: TextField(
                    controller: it.qtyCtrl,
                    readOnly: it.isEditMode,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(fontSize: 11),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      filled: it.isEditMode,
                      fillColor: it.isEditMode ? Colors.grey.shade100 : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: it.priceCtrl,
                    readOnly: it.isEditMode,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(fontSize: 11),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      filled: it.isEditMode,
                      fillColor: it.isEditMode ? Colors.grey.shade100 : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: Text('${NumberFormat('#,###').format(it.total)} ج',
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy))),
                if (!isEdit || _canFullEdit)
                  IconButton(
                      tooltip: isEdit ? 'حذف من الفاتورة عند الحفظ' : 'حذف',
                      icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                      onPressed: () => setState(() {
                            it.dispose();
                            _items.removeAt(idx);
                          })),
              ]),
            );
          }),
        ]),
      ],
    ]);
  }

  Widget _buildChargesSection() {
    if (_charges.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('لا توجد رسوم إضافية', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600))));
    }
    return Column(
        children: _charges.asMap().entries.map((entry) {
      final idx = entry.key;
      final ch = entry.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.06))),
        child: Column(children: [
          if (ch.isNew) ...[
            DropdownButtonFormField<String>(
              value: ch.chargeType,
              decoration: InputDecoration(
                labelText: 'نوع الرسم الجديد',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              ),
              items: const [
                DropdownMenuItem(value: 'Shipping', child: Text('شحن')),
                DropdownMenuItem(value: 'Installation', child: Text('تركيب')),
                DropdownMenuItem(value: 'Other', child: Text('أخرى')),
              ],
              onChanged: (value) => setState(() {
                ch.chargeType = value ?? 'Other';
              }),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(
                flex: 2,
                child: TextField(
                    controller: ch.descCtrl,
                    readOnly: ch.isEditMode,
                    style: GoogleFonts.cairo(fontSize: 11),
                    decoration: InputDecoration(
                        hintText: 'مثل: شحن، تركيب...',
                        hintStyle: GoogleFonts.cairo(fontSize: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: ch.isEditMode,
                        fillColor: ch.isEditMode ? Colors.grey.shade100 : null))),
            const SizedBox(width: 8),
            SizedBox(
                width: 110,
                child: TextField(
                    controller: ch.amountCtrl,
                    readOnly: ch.isEditMode,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(fontSize: 11),
                    decoration: InputDecoration(
                        labelText: 'المبلغ',
                        labelStyle: GoogleFonts.cairo(fontSize: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: ch.isEditMode,
                        fillColor: ch.isEditMode ? Colors.grey.shade100 : null))),
            if (!isEdit || ch.isNew)
              IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                  onPressed: () => setState(() {
                        ch.dispose();
                        _charges.removeAt(idx);
                      })),
          ]),
        ]),
      );
    }).toList());
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.22)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text('ملخص الفاتورة', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
          const Spacer(),
          if (isEdit)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('وضع التعديل - الإجماليات تتحدث تلقائياً',
                  style: GoogleFonts.cairo(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 12),
        _sumRow('إجمالي الأصناف:', '${NumberFormat('#,###').format(_totalAmount)} ج'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('خصم %:', style: GoogleFonts.cairo(fontSize: 12))),
          SizedBox(
              width: 100,
              child: TextField(
                  controller: _discountPctCtrl,
                  readOnly: isEdit && !_canFullEdit,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.cairo(fontSize: 12),
                  decoration: InputDecoration(
                      hintText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        ]),
        const SizedBox(height: 6),
        _sumRow('قيمة الخصم:', '-${NumberFormat('#,###').format(_discountAmount)} ج', color: Colors.red),
        _sumRow('الصافي:', '${NumberFormat('#,###').format(_netTotal)} ج'),
        _sumRow('رسوم إضافية:', '+${NumberFormat('#,###').format(_chargesTotal)} ج'),
        Divider(height: 16, color: Colors.black.withOpacity(0.08)),
        _sumRow('الإجمالي النهائي:', '${NumberFormat('#,###').format(_grandTotal)} ج', isBold: true, bg: true),
        Divider(height: 16, color: Colors.black.withOpacity(0.08)),
        if (_advanceTotal > 0) _sumRow('دفعات مقدمة مطبقة:', '${NumberFormat('#,###').format(_advanceTotal)} ج', color: Colors.green),
        if (!isEdit) ...[
          const SizedBox(height: 8),
          Text('دفعة فورية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _paidCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cairo(fontSize: 12),
                    decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        labelStyle: GoogleFonts.cairo(fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
            const SizedBox(width: 8),
            Expanded(
                child: DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: InputDecoration(
                        labelText: 'طريقة الدفع',
                        labelStyle: GoogleFonts.cairo(fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    items: [
                      DropdownMenuItem(value: 'Cash', child: Text('نقدي', style: GoogleFonts.cairo(fontSize: 12))),
                      DropdownMenuItem(value: 'Bank', child: Text('تحويل بنكي', style: GoogleFonts.cairo(fontSize: 12))),
                      DropdownMenuItem(value: 'Visa', child: Text('فيزا', style: GoogleFonts.cairo(fontSize: 12)))
                    ],
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'))),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          _sumRow('المدفوع سابقاً:', '${NumberFormat('#,###').format(_originalPaid)} ج', color: Colors.green),
        ],
        Divider(height: 16, color: Colors.black.withOpacity(0.08)),
        _sumRow('المتبقي:', '${NumberFormat('#,###').format(_remaining)} ج',
            isBold: true, color: _remaining > 0 ? Colors.red : Colors.green, remaining: true),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: _grandTotal > 0 ? ((_grandTotal - _remaining) / _grandTotal).clamp(0, 1) : 0,
                minHeight: 8,
                backgroundColor: Colors.black.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(_remaining > 0 ? Colors.orange : Colors.green))),
        if (isEdit) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: Text('💡 عند تعديل الخصم، الإجمالي النهائي والمتبقي يتحدثون تلقائياً. عند الحفظ سيتم إعادة حساب الإجماليات في قاعدة البيانات.',

                style: GoogleFonts.cairo(fontSize: 10, color: Colors.blue.shade700)),
          ),
        ],
      ]),
    );
  }

  Widget _sumRow(String label, String value, {bool isBold = false, Color? color, bool bg = false, bool remaining = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: bg || remaining ? 10 : 0, vertical: bg || remaining ? 8 : 4),
      decoration: BoxDecoration(
          color: bg
              ? AppColors.gold.withOpacity(0.12)
              : (remaining ? (color ?? Colors.red).withOpacity(0.08) : null),
          borderRadius: BorderRadius.circular(bg || remaining ? 10 : 0),
          border: bg
              ? Border.all(color: AppColors.gold.withOpacity(0.22))
              : (remaining ? Border.all(color: (color ?? Colors.red).withOpacity(0.20)) : null)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: isBold ? 13 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: AppColors.textSecondary(_isDark))),
        Text(value, style: GoogleFonts.cairo(fontSize: isBold ? 14 : 12, fontWeight: FontWeight.bold, color: color ?? AppColors.text(_isDark))),
      ]),
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
  int? selectedAlternativeId;
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
