import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_colors.dart';
import '../services/customer_care_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'client_card_screen.dart';
import 'complaint_details_screen.dart';
import 'customer_care_history_screen.dart';
import 'invoice/invoice_details_screen.dart';

class CustomerCareScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? initialKind;

  const CustomerCareScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialKind,
  });

  @override
  State<CustomerCareScreen> createState() => _CustomerCareScreenState();
}

class _CustomerCareScreenState extends State<CustomerCareScreen> {
  final CustomerCareService _service = CustomerCareService();
  Map<String, dynamic> _kpis = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  List<Map<String, dynamic>> _visits = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _deliveries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salesInvoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _complaints = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _callbacks = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  bool _includeContacted = false;
  String? _error;
  String _tab = 'visits';
  DateTime? _from;
  DateTime? _to;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;

  static const Map<String, String> _kindNames = <String, String>{
    'Visit': 'زيارات المعرض',
    'Delivery': 'بعد التسليم',
    'SalesInvoice': 'قبل التسليم',
    'ComplaintFollowUp': 'متابعة الشكاوى',
  };

  static const Map<String, String> _outcomeNames = <String, String>{
    'Positive': 'إيجابي وراضٍ',
    'Neutral': 'محايد',
    'Negative': 'سلبي أو مستاء',
    'NoAnswer': 'لم يرد',
    'NotInterested': 'غير مهتم',
    'CallbackLater': 'تواصل لاحقًا',
  };

  @override
  void initState() {
    super.initState();
    _tab = switch (widget.initialKind) {
      'Delivery' => 'deliveries',
      'SalesInvoice' => 'salesInvoices',
      'ComplaintFollowUp' => 'complaints',
      'CallbackLater' => 'callbacks',
      _ => 'visits',
    };
    _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  List<Map<String, dynamic>> get _rows => switch (_tab) {
        'deliveries' => _deliveries,
        'salesInvoices' => _salesInvoices,
        'complaints' => _complaints,
        'callbacks' => _callbacks,
        _ => _visits,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getDashboard(
        dateFrom: _from,
        dateTo: _to,
        includeContacted: _includeContacted,
      );
      if (!mounted) return;
      setState(() {
        _kpis = _map(data['kpis']);
        _capabilities = _map(data['capabilities']);
        _visits = _list(data['visits']);
        _deliveries = _list(data['deliveries']);
        _salesInvoices = _list(data['salesInvoices']);
        _complaints = _list(data['complaints']);
        _callbacks = _list(data['callbacks']);
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

  Future<void> _pickDate(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
    await _load();
  }

  Future<void> _log(Map<String, dynamic> row) async {
    if (!_can('canLog')) return;
    String outcome = '';
    String channel = '${row['Channel'] ?? 'اتصال'}';
    if (!const <String>['اتصال', 'واتساب', 'إيميل'].contains(channel)) {
      channel = 'اتصال';
    }
    int satisfaction = _int(row['Satisfaction']);
    final notes = TextEditingController();
    final employeeNotes = TextEditingController();
    DateTime? nextCallDate = DateTime.now().add(const Duration(days: 1));
    bool skipped = false;

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(_isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.goldDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['ClientName'] ?? 'عميل'}',
                          style: GoogleFonts.cairo(
                              color: AppColors.text(_isDark),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      Text('${row['Title'] ?? _kindName('${row['Kind']}')}',
                          style: GoogleFonts.cairo(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 10.5)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('نتيجة التواصل *',
                    style: GoogleFonts.cairo(
                        color: AppColors.text(_isDark),
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _outcomeNames.entries.map((entry) {
                  final selected = outcome == entry.key;
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(_outcomeIcon(entry.key),
                        size: 16,
                        color:
                            selected ? Colors.white : _outcomeColor(entry.key)),
                    label: Text(entry.value,
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: selected ? Colors.white : null)),
                    selectedColor: _outcomeColor(entry.key),
                    onSelected: (_) => setSheetState(() {
                      outcome = entry.key;
                      if (outcome != 'CallbackLater') nextCallDate = null;
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: InputDecoration(
                      labelText: 'قناة التواصل',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    items: const <String>['اتصال', 'واتساب', 'إيميل']
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => channel = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'تقييم الرضا',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return InkWell(
                          onTap: () =>
                              setSheetState(() => satisfaction = value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              value <= satisfaction
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.warning,
                              size: 21,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ]),
              if (outcome == 'CallbackLater') ...[
                const SizedBox(height: 11),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat_rounded,
                      color: AppColors.info),
                  title: Text('موعد التواصل القادم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                  subtitle: Text(_date(nextCallDate),
                      style: GoogleFonts.cairo(fontSize: 11)),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: sheetContext,
                      initialDate: nextCallDate ??
                          DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setSheetState(() => nextCallDate = date);
                    }
                  },
                ),
              ],
              const SizedBox(height: 11),
              TextField(
                controller: notes,
                maxLines: 3,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  labelText: 'ملاحظات العميل',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: employeeNotes,
                maxLines: 2,
                style: GoogleFonts.cairo(),
                decoration: InputDecoration(
                  labelText: 'انطباع الموظف الداخلي',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
              CheckboxListTile(
                value: skipped,
                contentPadding: EdgeInsets.zero,
                title: Text('إسقاط هذه المتابعة مؤقتًا',
                    style: GoogleFonts.cairo(fontSize: 11.5)),
                onChanged: (value) =>
                    setSheetState(() => skipped = value == true),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: outcome.isEmpty
                      ? null
                      : () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.save_rounded),
                  label: Text('حفظ الفيدباك',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (save != true) return;
    setState(() => _busy = true);
    try {
      final result = await _service.logOutcome({
        'feedbackId': row['ExistingFeedbackId'],
        'kind': row['Kind'],
        'partyId': row['PartyId'],
        'clientName': row['ClientName'],
        'phone': row['Phone'],
        'opportunityId': row['OpportunityId'],
        'transactionId': row['TransactionId'],
        'complaintId': row['ComplaintId'],
        'visitInteractionId': row['VisitInteractionId'],
        'sourceDate': row['SourceDate'],
        'channel': channel,
        'outcome': outcome,
        'satisfaction': satisfaction > 0 ? satisfaction : null,
        'notes': notes.text.trim(),
        'employeeNotes': employeeNotes.text.trim(),
        'nextCallDate':
            outcome == 'CallbackLater' ? nextCallDate?.toIso8601String() : null,
        'markSkipped': skipped,
      });
      if (!mounted) return;
      _message('${result['message'] ?? 'تم حفظ الفيدباك'}');
      await _load();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:${phone.trim()}'));
  }

  Future<void> _whatsapp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    var value = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.startsWith('0')) value = '2$value';
    await launchUrl(Uri.parse('https://wa.me/$value'),
        mode: LaunchMode.externalApplication);
  }

  void _openSource(Map<String, dynamic> row) {
    final kind = '${row['Kind'] ?? ''}';
    if (kind == 'ComplaintFollowUp' && _int(row['ComplaintId']) > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailsScreen(
            complaintId: _int(row['ComplaintId']),
            userId: widget.userId,
            username: widget.username,
          ),
        ),
      );
      return;
    }
    if ((kind == 'Delivery' || kind == 'SalesInvoice') &&
        _int(row['TransactionId']) > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(
            transactionId: _int(row['TransactionId']),
            username: widget.username,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCardScreen(
          userId: widget.userId,
          username: widget.username,
          initialPartyId: _int(row['PartyId']),
        ),
      ),
    );
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.cairo()),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text('خدمة العملاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerCareHistoryScreen(
                  userId: widget.userId,
                  username: widget.username,
                ),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'السجل والتقرير',
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل طوابير خدمة العملاء')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _filters()),
              SliverToBoxAdapter(child: _tabs()),
              if (_rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    message: 'لا توجد حالات في هذا الطابور',
                    hint:
                        'جرّب تغيير المدة أو إظهار الحالات التي تم التواصل معها',
                    icon: Icons.support_agent_rounded,
                    onRefresh: _load,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList.builder(
                    itemCount: _rows.length,
                    itemBuilder: (_, index) => _queueCard(_rows[index]),
                  ),
                ),
            ]),
          ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('متابعة تجربة العميل',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              Text('زيارات، فواتير، تسليمات، شكاوى، ومواعيد إعادة الاتصال',
                  style:
                      GoogleFonts.cairo(color: Colors.white60, fontSize: 10.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _kpi('زيارات مفتوحة', _kpis['OpenVisits'], Icons.storefront_rounded,
                AppColors.info, 'visits'),
            _kpi('بعد التسليم', _kpis['OpenDeliveries'],
                Icons.local_shipping_rounded, AppColors.success, 'deliveries'),
            _kpi('قبل التسليم', _kpis['OpenSalesInvoices'],
                Icons.receipt_long_rounded, AppColors.warning, 'salesInvoices'),
            _kpi('شكاوى', _kpis['OpenComplaints'], Icons.report_problem_rounded,
                AppColors.error, 'complaints'),
            _kpi('اتصال لاحق', _kpis['CallbackCount'],
                Icons.event_repeat_rounded, Colors.purple, 'callbacks'),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _miniStat('تم اليوم', '${_int(_kpis['DoneToday'])}'),
          _miniStat('إجمالي مكتمل', '${_int(_kpis['DoneTotal'])}'),
          _miniStat(
              'رضا متوسط',
              _kpis['AvgSatisfaction'] == null
                  ? '—'
                  : _num(_kpis['AvgSatisfaction']).toStringAsFixed(1)),
          _miniStat('إيجابي', '${_int(_kpis['PositiveCount'])}'),
        ]),
      ]),
    );
  }

  Widget _kpi(
      String label, dynamic value, IconData icon, Color color, String tab) {
    final active = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 108,
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? color : Colors.white12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          Text('${_int(value)}',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8.5)),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5)),
          Text(label,
              maxLines: 1,
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 8.5)),
        ]),
      );

  Widget _filters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: _dateButton('من', _from, () => _pickDate(true))),
          const SizedBox(width: 7),
          Expanded(child: _dateButton('إلى', _to, () => _pickDate(false))),
          if (_from != null || _to != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _load();
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ]),
        SwitchListTile.adaptive(
          value: _includeContacted,
          contentPadding: EdgeInsets.zero,
          title: Text('إظهار الحالات التي تم التواصل معها',
              style: GoogleFonts.cairo(fontSize: 11.5)),
          onChanged: (value) {
            setState(() => _includeContacted = value);
            _load();
          },
        ),
      ]),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_month_rounded, size: 16),
        label: Text(
            date == null ? label : DateFormat('yyyy/MM/dd').format(date),
            style: GoogleFonts.cairo(fontSize: 10)),
      );

  Widget _tabs() {
    final tabs = <(String, String)>[
      ('visits', 'الزيارات'),
      ('deliveries', 'بعد التسليم'),
      ('salesInvoices', 'قبل التسليم'),
      ('complaints', 'الشكاوى'),
      ('callbacks', 'اتصال لاحق'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(
        children: tabs.map((item) {
          final active = _tab == item.$1;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 7),
            child: ChoiceChip(
              selected: active,
              label: Text(item.$2,
                  style: GoogleFonts.cairo(
                      fontSize: 10.5, color: active ? Colors.white : null)),
              selectedColor: AppColors.navy,
              onSelected: (_) => setState(() => _tab = item.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _queueCard(Map<String, dynamic> row) {
    final kind = '${row['Kind'] ?? ''}';
    final status = '${row['FeedbackStatus'] ?? ''}';
    final callback = row['NextCallDate'] != null;
    final color = _kindColor(kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_kindIcon(kind), color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['ClientName'] ?? 'عميل'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('${row['Title'] ?? _kindName(kind)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(_isDark), fontSize: 10)),
            ]),
          ),
          if (status == 'Done')
            _badge('تم التواصل', AppColors.success)
          else if (status == 'Open' && callback)
            _badge('متابعة مجدولة', Colors.purple)
          else if (status == 'Skipped')
            _badge('مُسقطة', AppColors.error)
          else
            _badge('جديدة', color),
        ]),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 6, children: [
          _chip(Icons.category_outlined, _kindName(kind)),
          _chip(Icons.event_rounded, _date(row['SourceDate'])),
          if (callback)
            _chip(
              Icons.event_repeat_rounded,
              'المتابعة: ${_date(row['NextCallDate'])}',
              color: _callbackColor(row['NextCallDate']),
            ),
          if ((row['Channel'] ?? '').toString().isNotEmpty)
            _chip(Icons.forum_outlined, '${row['Channel']}'),
          if (_int(row['Satisfaction']) > 0)
            _chip(Icons.star_rounded, '${_int(row['Satisfaction'])}/5',
                color: AppColors.warning),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            onPressed: () => _openSource(row),
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'فتح المصدر',
          ),
          if ((row['Phone'] ?? '').toString().isNotEmpty) ...[
            IconButton(
              onPressed: () => _call('${row['Phone']}'),
              icon: const Icon(Icons.call_rounded, color: AppColors.success),
              tooltip: 'اتصال',
            ),
            IconButton(
              onPressed: () => _whatsapp('${row['Phone']}'),
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              tooltip: 'واتساب',
            ),
          ],
          const Spacer(),
          if (_can('canLog'))
            FilledButton.icon(
              onPressed: _busy ? null : () => _log(row),
              icon: const Icon(Icons.rate_review_rounded, size: 17),
              label: Text(
                row['ExistingFeedbackId'] == null ? 'تسجيل' : 'تحديث',
                style: GoogleFonts.cairo(fontSize: 10.5),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _chip(IconData icon, String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: (color ?? AppColors.navy).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14, color: color ?? AppColors.textSecondary(_isDark)),
          const SizedBox(width: 5),
          Text(text,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 9.5)),
        ]),
      );

  String _kindName(String kind) => _kindNames[kind] ?? kind;

  IconData _kindIcon(String kind) => switch (kind) {
        'Visit' => Icons.storefront_rounded,
        'Delivery' => Icons.local_shipping_rounded,
        'SalesInvoice' => Icons.receipt_long_rounded,
        'ComplaintFollowUp' => Icons.report_problem_rounded,
        _ => Icons.support_agent_rounded,
      };

  Color _kindColor(String kind) => switch (kind) {
        'Visit' => AppColors.info,
        'Delivery' => AppColors.success,
        'SalesInvoice' => AppColors.warning,
        'ComplaintFollowUp' => AppColors.error,
        _ => Colors.purple,
      };

  IconData _outcomeIcon(String outcome) => switch (outcome) {
        'Positive' => Icons.sentiment_very_satisfied_rounded,
        'Neutral' => Icons.sentiment_neutral_rounded,
        'Negative' => Icons.sentiment_dissatisfied_rounded,
        'NoAnswer' => Icons.phone_missed_rounded,
        'NotInterested' => Icons.block_rounded,
        'CallbackLater' => Icons.event_repeat_rounded,
        _ => Icons.help_outline_rounded,
      };

  Color _outcomeColor(String outcome) => switch (outcome) {
        'Positive' => AppColors.success,
        'Neutral' => AppColors.info,
        'Negative' => AppColors.error,
        'NoAnswer' => AppColors.warning,
        'NotInterested' => AppColors.neutral,
        'CallbackLater' => Colors.purple,
        _ => AppColors.navy,
      };

  Color _callbackColor(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return Colors.purple;
    return date.isBefore(DateTime.now()) ? AppColors.error : Colors.purple;
  }

  String _date(dynamic value) {
    if (value is DateTime) return DateFormat('yyyy/MM/dd').format(value);
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd').format(date);
  }
}
