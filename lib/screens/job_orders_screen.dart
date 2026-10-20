import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/app_colors.dart';
import '../services/job_order_service.dart';
import '../services/theme_service.dart';
import 'invoice/invoice_details_screen.dart';
import 'job_order_details_screen.dart';

class JobOrdersScreen extends StatefulWidget {
  final int userId;
  final String username;

  const JobOrdersScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<JobOrdersScreen> createState() => _JobOrdersScreenState();
}

class _JobOrdersScreenState extends State<JobOrdersScreen> {
  final JobOrderService _service = JobOrderService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  Map<String, dynamic> _company = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _exporting = false;
  String? _error;
  String _search = '';
  String _delivery = 'undelivered';
  String _type = 'all';
  String _due = 'all';
  DateTime? _dueFrom;
  DateTime? _dueTo;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;

  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);
  bool _can(String key) => _capabilities[key] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _load({bool append = false}) async {
    if (append) {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final data = await _service.getJobOrders(
        search: _search.trim().isEmpty ? null : _search.trim(),
        delivery: _delivery,
        type: _type,
        due: _due,
        dueFrom: _dueFrom,
        dueTo: _dueTo,
        page: append ? _page + 1 : 1,
      );
      final incoming = ((data['rows'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      final pagination = _map(data['pagination']);
      if (!mounted) return;
      setState(() {
        if (append) {
          _rows.addAll(incoming);
          _page++;
        } else {
          _rows = incoming;
          _page = _int(pagination['page']).clamp(1, 999999);
        }
        _stats = _map(data['stats']);
        _capabilities = _map(data['capabilities']);
        _company = _map(data['company']);
        _hasMore = pagination['hasMore'] == true;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = value;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        body: NestedScrollView(
          headerSliverBuilder:
              (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
            SliverAppBar(
              pinned: true,
              expandedHeight: 242,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text(
                'أوامر التشغيل',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: <Widget>[
                PopupMenuButton<String>(
                  tooltip: 'تصدير وطباعة',
                  enabled: !_exporting,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  onSelected: (String value) {
                    if (value == 'excel') _exportExcel();
                    if (value == 'pdf') _exportPdf();
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'excel',
                      child: Text('تصدير Excel بدون مبالغ',
                          style: GoogleFonts.cairo()),
                    ),
                    PopupMenuItem<String>(
                      value: 'pdf',
                      child: Text('طباعة PDF بدون مبالغ',
                          style: GoogleFonts.cairo()),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _hero(),
              ),
            ),
            SliverToBoxAdapter(child: _controls()),
          ],
          body: _body(),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 66, 16, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.factory_rounded,
                        color: AppColors.gold, size: 27),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Production Queue',
                          style: GoogleFonts.cairo(
                            color: AppColors.goldLight,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'أوامر التشغيل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'الفواتير التي تحتاج تشغيل وتسليم مرتبة بأقرب موعد',
                          style: GoogleFonts.cairo(
                              color: Colors.white60, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _stat('النتائج', _stats['TotalCount'],
                        Icons.list_alt_rounded, AppColors.gold),
                    const SizedBox(width: 8),
                    _stat('غير مسلّمة', _stats['UndeliveredCount'],
                        Icons.pending_actions_rounded, Colors.orange),
                    const SizedBox(width: 8),
                    _stat('متأخرة', _stats['OverdueCount'],
                        Icons.warning_amber_rounded, Colors.red),
                    const SizedBox(width: 8),
                    _stat('بها بدائل', _stats['WithAlternativesCount'],
                        Icons.tune_rounded, Colors.green),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_int(value)}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: GoogleFonts.cairo(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'بحث بالعميل أو الفاتورة أو الهاتف',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textHint(_isDark),
                      fontSize: 10.5,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.goldDark),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _search = '';
                              _load();
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: AppColors.inputFill(_isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip(
                    'undelivered', 'غير مسلّمة', Icons.pending_actions_rounded),
                const SizedBox(width: 7),
                _filterChip(
                    'delivered', 'تم التسليم', Icons.check_circle_rounded),
                const SizedBox(width: 7),
                _filterChip('all', 'كل الحالات', Icons.apps_rounded),
                const SizedBox(width: 10),
                _dueChip('overdue', 'متأخرة'),
                const SizedBox(width: 7),
                _dueChip('today', 'اليوم'),
                const SizedBox(width: 7),
                _dueChip('week', '7 أيام'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final active = _delivery == value;
    return ChoiceChip(
      selected: active,
      avatar: Icon(icon,
          size: 15, color: active ? Colors.white : AppColors.goldDark),
      label: Text(label, style: GoogleFonts.cairo(fontSize: 9.5)),
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(color: active ? Colors.white : _secondaryTextColor),
      onSelected: (_) {
        setState(() => _delivery = value);
        _load();
      },
    );
  }

  Widget _dueChip(String value, String label) {
    final active = _due == value;
    return ChoiceChip(
      selected: active,
      label: Text(label, style: GoogleFonts.cairo(fontSize: 9.5)),
      selectedColor: value == 'overdue' ? Colors.red : Colors.blue,
      labelStyle: TextStyle(color: active ? Colors.white : _secondaryTextColor),
      onSelected: (_) {
        setState(() => _due = active ? 'all' : value);
        _load();
      },
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('إعادة المحاولة: $_error', style: GoogleFonts.cairo()),
        ),
      );
    }
    if (_rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 100),
          const Icon(Icons.factory_outlined,
              size: 70, color: AppColors.goldDark),
          Text(
            'لا توجد أوامر تشغيل مطابقة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                color: _textColor, fontWeight: FontWeight.w800),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == _rows.length) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(append: true),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _loadingMore ? 'جاري التحميل...' : 'تحميل المزيد',
                  style: GoogleFonts.cairo(),
                ),
              ),
            );
          }
          return _card(_rows[index]);
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final id = _int(row['TransactionID']);
    final delivered = row['IsDelivered'] == true || row['IsDelivered'] == 1;
    final purchase = '${row['TransactionType']}' == 'Purchase';
    final due = DateTime.tryParse('${row['DueDate'] ?? ''}');
    final overdue = !delivered &&
        due != null &&
        DateUtils.dateOnly(due.toLocal())
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    final color = delivered
        ? Colors.green
        : overdue
            ? Colors.red
            : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => _openDetails(id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (purchase ? Colors.purple : Colors.blue)
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      purchase
                          ? Icons.local_shipping_rounded
                          : Icons.factory_rounded,
                      color: purchase ? Colors.purple : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${row['ReferenceNumber'] ?? '#$id'}',
                          style: GoogleFonts.cairo(
                            color: _textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          purchase ? 'أمر توريد' : 'أمر بيع',
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _badge(
                    delivered
                        ? 'تم التسليم'
                        : overdue
                            ? 'متأخر'
                            : 'غير مسلّم',
                    color,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.13),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.goldDark, size: 19),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${row['PartyName'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: _textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${row['Phone'] ?? ''}',
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_can('canSeeAmounts') && row['GrandTotal'] != null)
                    Text(
                      '${_money(row['GrandTotal'])} ج',
                      style: GoogleFonts.cairo(
                        color: AppColors.goldDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: <Widget>[
                  _info(
                      Icons.event_rounded,
                      due == null
                          ? 'موعد غير محدد'
                          : DateFormat('yyyy/MM/dd').format(due.toLocal())),
                  _info(Icons.inventory_2_rounded,
                      '${_int(row['ItemsCount'])} بند'),
                  _info(Icons.tune_rounded,
                      '${_int(row['AlternativeItemsCount'])} بديل'),
                  if (_int(row['MaxPeriodDays']) > 0)
                    _info(Icons.schedule_rounded,
                        '${_int(row['MaxPeriodDays'])} يوم'),
                  if ('${row['EmpName'] ?? ''}'.isNotEmpty)
                    _info(Icons.badge_rounded, '${row['EmpName']}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _openDetails(id),
                    icon: const Icon(Icons.factory_rounded, size: 17),
                    label: Text('أمر التشغيل', style: GoogleFonts.cairo()),
                  ),
                  if (_can('canEditDueDate') && !delivered)
                    TextButton.icon(
                      onPressed: () => _editDueDate(row),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 17),
                      label: Text('الموعد', style: GoogleFonts.cairo()),
                    ),
                  const Spacer(),
                  if (_can('canOpenInvoices'))
                    IconButton(
                      tooltip: 'فتح الفاتورة',
                      onPressed: () => _openInvoice(id, purchase),
                      icon: const Icon(Icons.receipt_long_rounded,
                          color: Colors.green),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.goldDark, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 8.8),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    String type = _type;
    DateTime? from = _dueFrom;
    DateTime? to = _dueTo;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) =>
              SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'فلاتر أوامر التشغيل',
                    style: GoogleFonts.cairo(
                      color: _textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'نوع الأمر'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                          value: 'all', child: Text('كل الأنواع')),
                      DropdownMenuItem<String>(
                          value: 'sale', child: Text('أوامر بيع')),
                      DropdownMenuItem<String>(
                          value: 'purchase', child: Text('أوامر توريد')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setSheetState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text('من تاريخ تسليم', style: GoogleFonts.cairo()),
                    subtitle: Text(from == null
                        ? 'غير محدد'
                        : DateFormat('yyyy/MM/dd').format(from!)),
                    trailing: from == null
                        ? null
                        : IconButton(
                            onPressed: () => setSheetState(() => from = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: () async {
                      final date = await _pickDate(from);
                      if (date != null) setSheetState(() => from = date);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text('إلى تاريخ تسليم', style: GoogleFonts.cairo()),
                    subtitle: Text(to == null
                        ? 'غير محدد'
                        : DateFormat('yyyy/MM/dd').format(to!)),
                    trailing: to == null
                        ? null
                        : IconButton(
                            onPressed: () => setSheetState(() => to = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: () async {
                      final date = await _pickDate(to);
                      if (date != null) setSheetState(() => to = date);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.check_rounded),
                      label: Text('تطبيق', style: GoogleFonts.cairo()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (apply == true) {
      setState(() {
        _type = type;
        _dueFrom = from;
        _dueTo = to;
      });
      _load();
    }
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
  }

  Future<void> _editDueDate(Map<String, dynamic> row) async {
    DateTime? due = DateTime.tryParse('${row['DueDate'] ?? ''}')?.toLocal();
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
          title: Text('تعديل تاريخ التسليم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_calendar_rounded),
                title: Text(due == null
                    ? 'اختر التاريخ'
                    : DateFormat('yyyy/MM/dd').format(due!)),
                onTap: () async {
                  final selected = await _pickDate(due);
                  if (selected != null) setDialogState(() => due = selected);
                },
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات التعديل'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed:
                  due == null ? null : () => Navigator.pop(dialogContext, true),
              child: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        final result = await _service.updateDueDate(
          id: _int(row['TransactionID']),
          dueDate: due,
          notes: notes.text.trim(),
        );
        if (mounted) _message('${result['message'] ?? 'تم تعديل التاريخ'}');
        await _load();
      } catch (error) {
        if (mounted) _message(error.toString(), error: true);
      }
    }
    notes.dispose();
  }

  void _openDetails(int id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JobOrderDetailsScreen(
          userId: widget.userId,
          username: widget.username,
          transactionId: id,
        ),
      ),
    ).then((_) => _load());
  }

  void _openInvoice(int id, bool purchase) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailsScreen(
          transactionId: id,
          username: widget.username,
          invoiceType: purchase ? 'Purchase' : 'Sale',
        ),
      ),
    );
  }

  String _money(dynamic value) {
    return NumberFormat('#,##0.##', 'en_US').format(_num(value));
  }

  List<Map<String, dynamic>> get _undeliveredRows => _rows
      .where((row) => !(row['IsDelivered'] == true || row['IsDelivered'] == 1))
      .toList();

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['أوامر التشغيل غير المسلمة'];
      sheet.appendRow(<excel.CellValue>[
        excel.TextCellValue('#'),
        excel.TextCellValue('النوع'),
        excel.TextCellValue('رقم الفاتورة'),
        excel.TextCellValue('العميل'),
        excel.TextCellValue('الموظف'),
        excel.TextCellValue('التليفون'),
        excel.TextCellValue('تاريخ الفاتورة'),
        excel.TextCellValue('التسليم المتوقع'),
        excel.TextCellValue('عدد البنود'),
        excel.TextCellValue('بدائل مختارة'),
      ]);
      for (var index = 0; index < _undeliveredRows.length; index++) {
        final row = _undeliveredRows[index];
        sheet.appendRow(<excel.CellValue>[
          excel.IntCellValue(index + 1),
          excel.TextCellValue(
              '${row['TransactionType']}' == 'Purchase' ? 'توريد' : 'بيع'),
          excel.TextCellValue('${row['ReferenceNumber'] ?? ''}'),
          excel.TextCellValue('${row['PartyName'] ?? ''}'),
          excel.TextCellValue('${row['EmpName'] ?? ''}'),
          excel.TextCellValue('${row['Phone'] ?? ''}'),
          excel.TextCellValue('${row['TransactionDate'] ?? ''}'),
          excel.TextCellValue('${row['DueDate'] ?? ''}'),
          excel.IntCellValue(_int(row['ItemsCount'])),
          excel.IntCellValue(_int(row['AlternativeItemsCount'])),
        ]);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/JobOrders_Undelivered_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(file.path,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
          ],
          text: 'أوامر التشغيل غير المسلّمة',
        ),
      );
    } catch (error) {
      if (mounted) _message('تعذر التصدير: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final regularData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final logoData = await rootBundle.load('assets/images/logo.png');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          header: (_) => pw.Column(
            children: <pw.Widget>[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Row(
                    children: <pw.Widget>[
                      pw.Image(logo, width: 45, height: 45),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: <pw.Widget>[
                          pw.Text(
                            '${_company['CompanyName'] ?? 'COCOBOLO'}',
                            style: pw.TextStyle(font: bold, fontSize: 14),
                          ),
                          pw.Text(
                            '${_company['Address'] ?? ''} ${_company['Phone1'] ?? ''}',
                            style: pw.TextStyle(font: regular, fontSize: 7),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    children: <pw.Widget>[
                      pw.Text(
                        'أوامر التشغيل غير المسلّمة',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 18,
                          color: const PdfColor.fromInt(0xFF1E3A8A),
                        ),
                      ),
                      pw.Text(
                        'تقرير تشغيلي — بدون مبالغ مالية',
                        style: pw.TextStyle(font: regular, fontSize: 8),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(font: regular, fontSize: 8),
                  ),
                ],
              ),
              pw.Divider(
                  color: const PdfColor.fromInt(0xFF0F172A), thickness: 1.5),
            ],
          ),
          build: (_) => <pw.Widget>[
            pw.TableHelper.fromTextArray(
              headers: <String>[
                '#',
                'النوع',
                'رقم الفاتورة',
                'العميل',
                'الموظف',
                'التليفون',
                'تاريخ الفاتورة',
                'التسليم المتوقع',
                'البنود',
                'البدائل',
              ],
              data: _undeliveredRows.asMap().entries.map<List<String>>((entry) {
                final row = entry.value;
                return <String>[
                  '${entry.key + 1}',
                  '${row['TransactionType']}' == 'Purchase' ? 'توريد' : 'بيع',
                  '${row['ReferenceNumber'] ?? ''}',
                  '${row['PartyName'] ?? ''}',
                  '${row['EmpName'] ?? '—'}',
                  '${row['Phone'] ?? '—'}',
                  _date(row['TransactionDate']),
                  _date(row['DueDate']),
                  '${_int(row['ItemsCount'])}',
                  '${_int(row['AlternativeItemsCount'])}',
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
              cellStyle: pw.TextStyle(font: regular, fontSize: 6.5),
              cellAlignment: pw.Alignment.centerRight,
            ),
          ],
          footer: (_) => pw.Center(
            child: pw.Text(
              'يعرض التقرير أوامر التشغيل غير المسلّمة فقط ولا يتضمن مبالغ مالية.',
              style: pw.TextStyle(
                  font: regular, fontSize: 7, color: PdfColors.grey600),
            ),
          ),
        ),
      );
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/JobOrders_Undelivered_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await document.save(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          text: 'أوامر التشغيل غير المسلّمة',
        ),
      );
    } catch (error) {
      if (mounted) _message('تعذر إنشاء PDF: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd').format(date.toLocal());
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
