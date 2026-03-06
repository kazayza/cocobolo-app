import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/cashbox_service.dart';
import '../services/permission_service.dart';
import '../services/cashbox_report_service.dart';
import 'cashbox_manual_screen.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class CashboxTransactionsScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const CashboxTransactionsScreen({
    Key? key,
    this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<CashboxTransactionsScreen> createState() => _CashboxTransactionsScreenState();
}

class _CashboxTransactionsScreenState extends State<CashboxTransactionsScreen> {
  // البيانات
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> cashboxes = [];
  bool loading = true;

  // ✅ الإحصائيات المحسوبة من النتائج
  double totalIn = 0;
  double totalOut = 0;
  double balance = 0;

  // ✅ حالة الفلاتر (مطوية/مفتوحة)
  bool filtersExpanded = false;

  // الفلاتر
  int? selectedCashboxId;
  String selectedTransactionType = 'الكل';
  String selectedReferenceType = 'الكل';
  DateTime? fromDate;
  DateTime? toDate;

  // قوائم الفلاتر
  final List<String> transactionTypes = ['الكل', 'قبض', 'صرف'];
  final List<Map<String, String>> referenceTypes = [
    {'value': 'الكل', 'label': 'الكل'},
    {'value': 'Manual', 'label': 'يدوي'},
    {'value': 'Transfer', 'label': 'تحويل'},
    {'value': 'Payment', 'label': 'سداد فاتورة'},
    {'value': 'Expense', 'label': 'مصروف'},
    {'value': 'Payroll', 'label': 'راتب'},
    {'value': 'AdvanceExpense', 'label': 'مصروف مقدم'},
    {'value': 'Charge', 'label': 'رسوم'},
  ];

  @override
  void initState() {
    super.initState();
    fromDate = DateTime.now().subtract(const Duration(days: 30));
    toDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    
    final cashboxList = await CashboxService.getAllCashboxes();
    
    setState(() {
      cashboxes = cashboxList;
    });
    
    await _loadTransactions();
    
    setState(() {
      loading = false;
    });
  }

  Future<void> _loadTransactions() async {
    final data = await CashboxService.getTransactions(
      cashboxId: selectedCashboxId,
      startDate: fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate!) : null,
      endDate: toDate != null ? DateFormat('yyyy-MM-dd').format(toDate!) : null,
      transactionType: selectedTransactionType,
      referenceType: selectedReferenceType,
    );
    
    // ✅ حساب الإحصائيات من النتائج المفلترة
    _calculateStats(data);
    
    setState(() {
      transactions = data;
    });
  }

  // ✅ دالة حساب الإحصائيات
  void _calculateStats(List<Map<String, dynamic>> data) {
    double inTotal = 0;
    double outTotal = 0;
    
    for (var t in data) {
      final amount = (t['Amount'] ?? 0).toDouble();
      if (t['TransactionType'] == 'قبض') {
        inTotal += amount;
      } else if (t['TransactionType'] == 'صرف') {
        outTotal += amount;
      }
    }
    
    setState(() {
      totalIn = inTotal;
      totalOut = outTotal;
      balance = inTotal - outTotal;
    });
  }

  Future<void> _applyFilters() async {
    setState(() => loading = true);
    await _loadTransactions();
    setState(() => loading = false);
  }

  void _clearFilters() {
    setState(() {
      selectedCashboxId = null;
      selectedTransactionType = 'الكل';
      selectedReferenceType = 'الكل';
      fromDate = DateTime.now().subtract(const Duration(days: 30));
      toDate = DateTime.now();
    });
    _applyFilters();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
        ),
        child: child!,
      ),
    );
    
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
      _applyFilters();
    }
  }

  // ✅ عرض تفاصيل الحركة
  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final isCredit = transaction['TransactionType'] == 'قبض';
    final Color typeColor = isCredit ? Colors.green : Colors.red;
    
    String dateStr = '';
    String timeStr = '';
    if (transaction['TransactionDate'] != null) {
      try {
        final date = DateTime.parse(transaction['TransactionDate']);
        dateStr = DateFormat('yyyy/MM/dd').format(date);
        timeStr = DateFormat('hh:mm a').format(date);
      } catch (e) {
        dateStr = transaction['TransactionDate'].toString();
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // المقبض
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // العنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction['TransactionType'] ?? '',
                        style: GoogleFonts.cairo(
                          color: typeColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        transaction['CashBoxName'] ?? '',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'} ${_formatCurrency(transaction['Amount'] ?? 0)}',
                  style: GoogleFonts.cairo(
                    color: typeColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            Divider(color: Colors.grey[800]),
            const SizedBox(height: 16),
            
            // التفاصيل
            _buildDetailRow(Icons.calendar_today, 'التاريخ', dateStr),
            _buildDetailRow(Icons.access_time, 'الوقت', timeStr),
            _buildDetailRow(
              Icons.category,
              'نوع المرجع',
              _getReferenceTypeLabel(transaction['ReferenceType']),
            ),
            if (transaction['ReferenceID'] != null)
              _buildDetailRow(Icons.tag, 'رقم المرجع', transaction['ReferenceID'].toString()),
            _buildDetailRow(Icons.person, 'بواسطة', transaction['CreatedBy'] ?? '---'),
            
            if (transaction['Notes'] != null && transaction['Notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes, color: Colors.grey[500], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'بيان ووصف',
                          style: GoogleFonts.cairo(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transaction['Notes'],
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // زر الإغلاق
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE8B923), size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
    // ══════════════════════════════════════════
  // ✅ دوال التقارير - أضفها هنا
  // ══════════════════════════════════════════

  Future<void> _handleReportAction(String action) async {
    if (transactions.isEmpty) {
      _showMessage('لا توجد بيانات للتصدير', isError: true);
      return;
    }

    String? cashboxName;
    if (selectedCashboxId != null) {
      final cashbox = cashboxes.firstWhere(
        (c) => c['CashBoxID'] == selectedCashboxId,
        orElse: () => {},
      );
      cashboxName = cashbox['CashBoxName'];
    }

    final fromDateStr = fromDate != null ? DateFormat('yyyy/MM/dd').format(fromDate!) : null;
    final toDateStr = toDate != null ? DateFormat('yyyy/MM/dd').format(toDate!) : null;

    try {
      switch (action) {
        case 'pdf':
          await _exportPDF(cashboxName, fromDateStr, toDateStr);
          break;
        case 'excel':
          await _exportExcel(cashboxName, fromDateStr, toDateStr);
          break;
        case 'print':
          await _printReport(cashboxName, fromDateStr, toDateStr);
          break;
      }
    } catch (e) {
      _showMessage('حدث خطأ: $e', isError: true);
    }
  }

  Future<void> _exportPDF(String? cashboxName, String? fromDateStr, String? toDateStr) async {
    _showMessage('جاري إنشاء ملف PDF...');

    final pdfBytes = await CashboxReportService.generatePDF(
      transactions: transactions,
      totalIn: totalIn,
      totalOut: totalOut,
      balance: balance,
      cashboxName: cashboxName,
      fromDate: fromDateStr,
      toDate: toDateStr,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'cashbox_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _exportExcel(String? cashboxName, String? fromDateStr, String? toDateStr) async {
    _showMessage('جاري إنشاء ملف Excel...');

    final filePath = await CashboxReportService.generateExcel(
      transactions: transactions,
      totalIn: totalIn,
      totalOut: totalOut,
      balance: balance,
      cashboxName: cashboxName,
      fromDate: fromDateStr,
      toDate: toDateStr,
    );

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'تقرير حركات الخزينة',
    );
  }

  Future<void> _printReport(String? cashboxName, String? fromDateStr, String? toDateStr) async {
    final pdfBytes = await CashboxReportService.generatePDF(
      transactions: transactions,
      totalIn: totalIn,
      totalOut: totalOut,
      balance: balance,
      cashboxName: cashboxName,
      fromDate: fromDateStr,
      toDate: toDateStr,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'تقرير حركات الخزينة',
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.cairo())),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummaryHeader(),
          _buildFiltersSection(),
          Expanded(
            child: loading
                ? _buildLoadingState()
                : transactions.isEmpty
                    ? _buildEmptyState()
                    : _buildTransactionsList(),
          ),
        ],
      ),
      floatingActionButton: PermissionService().canAdd('frm_CashBoxManual')
    ? FloatingActionButton(
        onPressed: () async {
          // فتح شاشة الإضافة
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CashboxManualScreen(
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
          
          // تحديث البيانات لو رجع من الشاشة
          if (result == true || result == null) {
            _loadData();
          }
        },
        backgroundColor: const Color(0xFFE8B923),
        child: const Icon(Icons.add, color: Colors.black),
      )
    : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFFE8B923), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'حركات الخزينة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
  // عدد النتائج
  Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8B923).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${transactions.length} حركة',
        style: GoogleFonts.cairo(
          color: const Color(0xFFE8B923),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),
  
  // ✅ زر التقرير
  PopupMenuButton<String>(
    icon: const Icon(Icons.file_download, size: 20),
    color: const Color(0xFF2A2A2A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    onSelected: (value) => _handleReportAction(value),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'pdf',
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Text('تصدير PDF', style: GoogleFonts.cairo(color: Colors.white)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'excel',
        child: Row(
          children: [
            const Icon(Icons.table_chart, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Text('تصدير Excel', style: GoogleFonts.cairo(color: Colors.white)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'print',
        child: Row(
          children: [
            const Icon(Icons.print, color: Colors.blue, size: 20),
            const SizedBox(width: 10),
            Text('طباعة', style: GoogleFonts.cairo(color: Colors.white)),
          ],
        ),
      ),
    ],
  ),
  
  IconButton(
    icon: const Icon(Icons.refresh, size: 18),
    onPressed: _loadData,
  ),
],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // ✅ الفترة المحددة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range, color: Colors.grey[400], size: 14),
                const SizedBox(width: 6),
                Text(
                  '${fromDate != null ? DateFormat('MM/dd').format(fromDate!) : '---'} - ${toDate != null ? DateFormat('MM/dd').format(toDate!) : '---'}',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'إجمالي القبض',
                _formatCurrency(totalIn),
                Icons.arrow_downward,
                Colors.green,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildSummaryItem(
                'إجمالي الصرف',
                _formatCurrency(totalOut),
                Icons.arrow_upward,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: balance >= 0 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: balance >= 0 
                    ? Colors.green.withOpacity(0.3) 
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance,
                  color: balance >= 0 ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'صافي الفترة: ',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatCurrency(balance),
                  style: GoogleFonts.cairo(
                    color: balance >= 0 ? Colors.green : Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ✅ الفلاتر القابلة للطي
  Widget _buildFiltersSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          // ✅ زر الطي/الفتح + التاريخ السريع
          InkWell(
            onTap: () {
              setState(() {
                filtersExpanded = !filtersExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    filtersExpanded ? Icons.filter_list_off : Icons.filter_list,
                    color: const Color(0xFFE8B923),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الفلاتر',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // ✅ عرض الفلاتر النشطة
                  if (_hasActiveFilters()) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B923).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'نشط',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFE8B923),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // زر مسح الفلاتر
                  if (_hasActiveFilters())
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.clear_all, color: Colors.red, size: 16),
                      ),
                    ),
                  
                  const SizedBox(width: 10),
                  
                  Icon(
                    filtersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          
          // ✅ محتوى الفلاتر (قابل للطي)
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: _buildFiltersContent(),
            crossFadeState: filtersExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedCashboxId != null ||
        selectedTransactionType != 'الكل' ||
        selectedReferenceType != 'الكل';
  }

  Widget _buildFiltersContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // الصف الأول: الخزنة ونوع العملية
          Row(
            children: [
              Expanded(child: _buildCashboxDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildTransactionTypeDropdown()),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // الصف التاني: نوع المرجع
          _buildReferenceTypeDropdown(),
          
          const SizedBox(height: 12),
          
          // الصف التالت: التاريخ
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  'من: ${fromDate != null ? DateFormat('MM/dd').format(fromDate!) : '---'}',
                  Icons.calendar_today,
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateButton(
                  'إلى: ${toDate != null ? DateFormat('MM/dd').format(toDate!) : '---'}',
                  Icons.calendar_month,
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashboxDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedCashboxId,
          hint: Text(
            'كل الخزائن',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12),
          ),
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE8B923), size: 20),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'كل الخزائن',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
              ),
            ),
            ...cashboxes.map((c) => DropdownMenuItem<int?>(
              value: c['CashBoxID'],
              child: Text(
                c['CashBoxName'] ?? '',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
              ),
            )),
          ],
          onChanged: (value) {
            setState(() => selectedCashboxId = value);
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildTransactionTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTransactionType,
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE8B923), size: 20),
          items: transactionTypes.map((type) => DropdownMenuItem(
            value: type,
            child: Row(
              children: [
                if (type != 'الكل')
                  Icon(
                    type == 'قبض' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: type == 'قبض' ? Colors.green : Colors.red,
                    size: 14,
                  ),
                if (type != 'الكل') const SizedBox(width: 6),
                Text(
                  type,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          )).toList(),
          onChanged: (value) {
            setState(() => selectedTransactionType = value!);
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildReferenceTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedReferenceType,
          dropdownColor: const Color(0xFF2A2A2A),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE8B923), size: 20),
          items: referenceTypes.map((type) => DropdownMenuItem(
            value: type['value'],
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getReferenceTypeColor(type['value']),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  type['label']!,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          )).toList(),
          onChanged: (value) {
            setState(() => selectedReferenceType = value!);
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8B923), size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionCard(transactions[index], index);
      },
    );
  }

  // ✅ كارت قابل للضغط
  Widget _buildTransactionCard(Map<String, dynamic> transaction, int index) {
    final isCredit = transaction['TransactionType'] == 'قبض';
    final Color typeColor = isCredit ? Colors.green : Colors.red;
    final IconData typeIcon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
    
    String dateStr = '';
    if (transaction['TransactionDate'] != null) {
      try {
        final date = DateTime.parse(transaction['TransactionDate']);
        dateStr = DateFormat('MM/dd - hh:mm a').format(date);
      } catch (e) {
        dateStr = transaction['TransactionDate'].toString();
      }
    }

    String refTypeLabel = _getReferenceTypeLabel(transaction['ReferenceType']);

    return GestureDetector(
      onTap: () => _showTransactionDetails(transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E1E1E),
              const Color(0xFF252525),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            right: BorderSide(color: typeColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // أيقونة النوع
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              
              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          transaction['CashBoxName'] ?? '',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getReferenceTypeColor(transaction['ReferenceType']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            refTypeLabel,
                            style: GoogleFonts.cairo(
                              color: _getReferenceTypeColor(transaction['ReferenceType']),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.cairo(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              
              // المبلغ
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'} ${_formatCurrency(transaction['Amount'] ?? 0)}',
                    style: GoogleFonts.cairo(
                      color: typeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.chevron_left,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.1);
  }

  String _getReferenceTypeLabel(String? type) {
    switch (type) {
      case 'Manual': return 'يدوي';
      case 'Transfer': return 'تحويل';
      case 'Payment': return 'سداد';
      case 'Expense': return 'مصروف';
      case 'Payroll': return 'راتب';
      case 'AdvanceExpense': return 'مقدم';
      case 'Charge': return 'رسوم';
      default: return type ?? '---';
    }
  }

  Color _getReferenceTypeColor(String? type) {
    switch (type) {
      case 'Manual': return Colors.blue;
      case 'Transfer': return Colors.purple;
      case 'Payment': return Colors.green;
      case 'Expense': return Colors.orange;
      case 'Payroll': return Colors.teal;
      case 'AdvanceExpense': return Colors.amber;
      case 'Charge': return Colors.pink;
      default: return Colors.grey;
    }
  }

  String _formatCurrency(dynamic amount) {
    final num = (amount is String) ? double.tryParse(amount) ?? 0 : amount.toDouble();
    return NumberFormat('#,##0.00', 'en').format(num);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFE8B923),
            strokeWidth: 2,
          ).animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الحركات...',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 50,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حركات',
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تغيير الفلاتر أو نطاق التاريخ',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'إعادة تعيين الفلاتر',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE8B923),
              side: const BorderSide(color: Color(0xFFE8B923)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}