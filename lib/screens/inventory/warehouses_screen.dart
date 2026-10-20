import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../services/app_colors.dart';
import '../../services/inventory_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/inventory_design.dart';

class WarehousesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const WarehousesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<dynamic> _warehouses = [];
  List<dynamic> _branches = [];
  int? _branchFilter;
  String _statusFilter = 'all';

  bool get _isDark => ThemeService().isDarkMode;

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _warehouses
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((warehouse) {
          final active = warehouse['IsActive'] == true ||
              warehouse['IsActive'] == 1;
          if (_statusFilter == 'active' && !active) return false;
          if (_statusFilter == 'inactive' && active) return false;
          if (_branchFilter != null &&
              (warehouse['BranchId'] ?? warehouse['BranchID']) !=
                  _branchFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return [
            warehouse['WarehouseName'],
            warehouse['Location'],
            warehouse['BranchNameAr'],
            warehouse['Notes'],
          ].join(' ').toLowerCase().contains(query);
        })
        .toList();
  }

  int get _activeCount => _warehouses
      .where((w) => w['IsActive'] == true || w['IsActive'] == 1)
      .length;
  int get _inactiveCount => _warehouses.length - _activeCount;
  int get _productsCount => _warehouses.fold(
        0,
        (sum, w) => sum + _int(w['ProductsCount']),
      );
  int get _totalQuantity => _warehouses.fold(
        0,
        (sum, w) => sum + _int(w['TotalQuantity']),
      );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<List<dynamic>>([
        InventoryService.getAllWarehouses(),
        InventoryService.getBranches(),
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0];
        _branches = results[1];
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

  String _branchName(Map<String, dynamic> warehouse) {
    final direct = warehouse['BranchNameAr'] ?? warehouse['BranchName'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    final branchId = warehouse['BranchId'] ?? warehouse['BranchID'];
    if (branchId == null) return 'غير مرتبط بفرع';
    final branch = _branches.cast<dynamic>().firstWhere(
          (b) => (b['BranchId'] ?? b['BranchID']) == branchId,
          orElse: () => null,
        );
    return branch == null
        ? 'غير مرتبط بفرع'
        : '${branch['BranchNameAr'] ?? branch['BranchName'] ?? ''}';
  }

  Future<void> _showEditor({Map<String, dynamic>? warehouse}) async {
    final nameController = TextEditingController(
      text: warehouse?['WarehouseName']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: warehouse?['Location']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: warehouse?['Notes']?.toString() ?? '',
    );
    int? branchId = warehouse?['BranchId'] ?? warehouse?['BranchID'];
    bool active = warehouse == null ||
        warehouse['IsActive'] == true ||
        warehouse['IsActive'] == 1;

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.card(_isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        warehouse == null
                            ? Icons.add_business_rounded
                            : Icons.edit_location_alt_rounded,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warehouse == null ? 'إضافة مخزن جديد' : 'تعديل المخزن',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameController,
                  decoration: inventoryInputDecoration(
                    context,
                    label: 'اسم المخزن *',
                    icon: Icons.warehouse_rounded,
                  ),
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<int?>(
                  value: branchId,
                  isExpanded: true,
                  decoration: inventoryInputDecoration(
                    context,
                    label: 'الفرع',
                    icon: Icons.business_rounded,
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('بدون فرع', style: GoogleFonts.cairo()),
                    ),
                    ..._branches.map(
                      (branch) => DropdownMenuItem<int?>(
                        value: branch['BranchId'] ?? branch['BranchID'],
                        child: Text(
                          branch['BranchNameAr'] ??
                              branch['BranchName'] ??
                              '',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setModalState(() => branchId = value);
                  },
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: locationController,
                  decoration: inventoryInputDecoration(
                    context,
                    label: 'الموقع',
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(height: 11),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: inventoryInputDecoration(
                    context,
                    label: 'ملاحظات',
                    icon: Icons.notes_rounded,
                  ),
                ),
                if (warehouse != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: active,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'المخزن نشط',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'المخازن غير النشطة لا تظهر في عمليات الحركة الجديدة.',
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    onChanged: (value) => setModalState(() => active = value),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) return;
                          Navigator.pop(sheetContext, true);
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(
                          warehouse == null ? 'إضافة المخزن' : 'حفظ التعديلات',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (save != true) {
      nameController.dispose();
      locationController.dispose();
      notesController.dispose();
      return;
    }

    setState(() => _saving = true);
    try {
      final body = jsonEncode({
        'warehouseName': nameController.text.trim(),
        'location': locationController.text.trim(),
        'notes': notesController.text.trim(),
        'branchId': branchId,
        'isActive': active,
        'createdBy': widget.username,
      });
      final id = warehouse?['WarehouseID'] ?? warehouse?['WarehouseId'];
      final response = warehouse == null
          ? await http.post(
              Uri.parse('$baseUrl/api/inventory/warehouses'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
          : await http.put(
              Uri.parse('$baseUrl/api/inventory/warehouses/$id'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            );
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw InventoryApiException(
          decoded['message']?.toString() ?? 'فشل حفظ بيانات المخزن',
          statusCode: response.statusCode,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warehouse == null
                ? 'تمت إضافة المخزن بنجاح'
                : 'تم حفظ تعديلات المخزن',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      nameController.dispose();
      locationController.dispose();
      notesController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _branchFilter = null;
      _statusFilter = 'all';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(
            'إدارة المخازن',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          onPressed: _saving ? null : () => _showEditor(),
          icon: const Icon(Icons.add_business_rounded),
          label: Text(
            'مخزن جديد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              InventoryHero(
                icon: Icons.warehouse_rounded,
                title: 'إدارة المخازن والفروع',
                subtitle:
                    'راجع مواقع التخزين وحالتها والأرصدة المسجلة داخل كل مخزن.',
                stats: [
                  InventoryHeroStat(
                    icon: Icons.warehouse_rounded,
                    label: 'إجمالي المخازن',
                    value: '${_warehouses.length}',
                    color: Colors.white,
                  ),
                  InventoryHeroStat(
                    icon: Icons.check_circle_rounded,
                    label: 'نشط',
                    value: '$_activeCount',
                    color: const Color(0xFF6EE7B7),
                  ),
                  InventoryHeroStat(
                    icon: Icons.category_rounded,
                    label: 'أصناف برصيد',
                    value: '$_productsCount',
                    color: AppColors.gold,
                  ),
                  InventoryHeroStat(
                    icon: Icons.inventory_2_rounded,
                    label: 'إجمالي الوحدات',
                    value: '$_totalQuantity',
                    color: const Color(0xFF93C5FD),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InventorySection(
                title: 'تصفية المخازن',
                subtitle: 'ابحث بالاسم أو الموقع وحدد الفرع والحالة.',
                icon: Icons.tune_rounded,
                color: AppColors.gold,
                trailing: IconButton(
                  tooltip: 'إعادة ضبط',
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: inventoryInputDecoration(
                        context,
                        label: 'بحث',
                        hint: 'اسم المخزن، الموقع أو الفرع',
                        icon: Icons.search_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 620;
                        final branch = _branchDropdown();
                        final status = _statusSelector();
                        if (compact) {
                          return Column(
                            children: [
                              branch,
                              const SizedBox(height: 10),
                              status,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: branch),
                            const SizedBox(width: 10),
                            Expanded(child: status),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                InventorySection(
                  title: 'تعذر تحميل المخازن',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                )
              else if (_filtered.isEmpty)
                InventorySection(
                  title: 'لا توجد مخازن مطابقة',
                  subtitle: _warehouses.isEmpty
                      ? 'لم يرجع الخادم أي مخازن. راجع الاتصال أو أضف مخزنًا جديدًا.'
                      : 'غيّر البحث أو الفلاتر الحالية.',
                  icon: Icons.warehouse_outlined,
                  color: AppColors.gold,
                  child: const SizedBox.shrink(),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      'المخازن المسجلة',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_filtered.length} مخزن',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary(_isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._filtered.map(
                  (warehouse) => _WarehouseCard(
                    warehouse: warehouse,
                    branchName: _branchName(warehouse),
                    onEdit: () => _showEditor(warehouse: warehouse),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<int?>(
      value: _branchFilter,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'الفرع',
        icon: Icons.business_rounded,
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('كل الفروع', style: GoogleFonts.cairo()),
        ),
        ..._branches.map(
          (branch) => DropdownMenuItem<int?>(
            value: branch['BranchId'] ?? branch['BranchID'],
            child: Text(
              branch['BranchNameAr'] ?? branch['BranchName'] ?? '',
              style: GoogleFonts.cairo(),
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _branchFilter = value),
    );
  }

  Widget _statusSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'all',
          label: Text('الكل'),
          icon: Icon(Icons.select_all_rounded),
        ),
        ButtonSegment(
          value: 'active',
          label: Text('نشط'),
          icon: Icon(Icons.check_circle_outline_rounded),
        ),
        ButtonSegment(
          value: 'inactive',
          label: Text('متوقف'),
          icon: Icon(Icons.pause_circle_outline_rounded),
        ),
      ],
      selected: {_statusFilter},
      onSelectionChanged: (values) {
        setState(() => _statusFilter = values.first);
      },
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final Map<String, dynamic> warehouse;
  final String branchName;
  final VoidCallback onEdit;

  const _WarehouseCard({
    required this.warehouse,
    required this.branchName,
    required this.onEdit,
  });

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeService().isDarkMode;
    final active =
        warehouse['IsActive'] == true || warehouse['IsActive'] == 1;
    final stateColor =
        active ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final location = '${warehouse['Location'] ?? ''}'.trim();
    final notes = '${warehouse['Notes'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(dark),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: stateColor.withValues(alpha: 0.17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: AppColors.navy,
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        warehouse['WarehouseName'] ?? 'مخزن بدون اسم',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        active ? 'نشط' : 'متوقف',
                        style: GoogleFonts.cairo(
                          color: stateColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _line(Icons.business_rounded, branchName),
                if (location.isNotEmpty)
                  _line(Icons.location_on_outlined, location),
                if (notes.isNotEmpty)
                  _line(Icons.notes_rounded, notes, maxLines: 2),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _badge(
                      Icons.category_outlined,
                      '${_int(warehouse['ProductsCount'])} صنف',
                      const Color(0xFF2563EB),
                    ),
                    _badge(
                      Icons.inventory_2_outlined,
                      '${_int(warehouse['TotalQuantity'])} وحدة',
                      const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تعديل المخزن',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, color: AppColors.gold),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontSize: 10.5, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
