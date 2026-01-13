import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/expense_service.dart';

class ExpenseReportsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String initialPeriod;

  const ExpenseReportsScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.initialPeriod = 'هذا الشهر',
  }) : super(key: key);

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  // بيانات التقرير
  double totalExpenses = 0.0;
  int transactionsCount = 0;
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;
  
  // الفلاتر
  String _selectedPeriod = 'هذا الشهر';
  List<String> periods = ['اليوم', 'أمس', 'الأسبوع', 'هذا الشهر', 'الشهر الماضي', 'مخصص'];
  DateTimeRange? _selectedDateRange;
  
  // أنواع التقارير
  String _selectedReportType = 'إحصائي';
  List<String> reportTypes = ['إحصائي', 'تفصيلي', 'التصنيفات', 'المقارنة'];
  
  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _initDateRange();
    _loadReportData();
  }
  
  void _initDateRange() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    _selectedDateRange = DateTimeRange(start: startDate, end: now);
  }
  
  Future<void> _loadReportData() async {
    setState(() => isLoading = true);
    
    try {
      final dateRange = _getDateRangeForPeriod(_selectedPeriod);
      
      // جلب المصروفات للفترة المحددة
      expenses = await ExpenseService.getExpensesForChart(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      
      // حساب الإجمالي وعدد المعاملات
      totalExpenses = expenses.fold(0.0, (sum, expense) {
        return sum + (expense['Amount'] as double);
      });
      
      transactionsCount = expenses.length;
      
    } catch (e) {
      print('❌ خطأ في تحميل بيانات التقرير: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  DateTimeRange _getDateRangeForPeriod(String period) {
    final now = DateTime.now();
    
    switch (period) {
      case 'اليوم':
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
        
      case 'أمس':
        final yesterday = now.subtract(Duration(days: 1));
        final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        return DateTimeRange(start: start, end: yesterday);
        
      case 'الأسبوع':
        final weekAgo = now.subtract(Duration(days: 7));
        return DateTimeRange(start: weekAgo, end: now);
        
      case 'هذا الشهر':
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
        
      case 'الشهر الماضي':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: end);
        
      case 'مخصص':
        return _selectedDateRange ?? DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
        
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'تقارير المصروفات',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color(0xFFE8B923),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.black),
            onPressed: _shareReport,
            tooltip: 'مشاركة التقرير',
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.black),
            onPressed: _exportReport,
            tooltip: 'تصدير التقرير',
          ),
        ],
      ),
      body: isLoading 
          ? _buildLoading()
          : _buildReportContent(),
    );
  }
  
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE8B923)),
          SizedBox(height: 20),
          Text(
            'جاري تحميل بيانات التقرير...',
            style: GoogleFonts.cairo(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== 1. فلاتر التقرير =====
            _buildReportFilters(),
            SizedBox(height: 20),
            
            // ===== 2. ملخص سريع =====
            _buildQuickSummary(),
            SizedBox(height: 20),
            
            // ===== 3. محتوى التقرير حسب النوع =====
            _buildReportByType(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  // 1. فلاتر التقرير
  Widget _buildReportFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE8B923).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إعدادات التقرير',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.filter_alt, color: Color(0xFFE8B923), size: 20),
            ],
          ),
          SizedBox(height: 16),
          
          // نوع التقرير
          Text(
            'نوع التقرير',
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reportTypes.map((type) {
              final isSelected = _selectedReportType == type;
              return FilterChip(
                label: Text(
                  type,
                  style: GoogleFonts.cairo(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: Color(0xFFE8B923),
                backgroundColor: Color(0xFF2A2A2A),
                onSelected: (selected) {
                  setState(() {
                    _selectedReportType = type;
                  });
                },
              );
            }).toList(),
          ),
          
          SizedBox(height: 16),
          
          // الفترة الزمنية
          Text(
            'الفترة الزمنية',
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periods.map((period) {
              final isSelected = _selectedPeriod == period;
              return FilterChip(
                label: Text(
                  period,
                  style: GoogleFonts.cairo(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: Color(0xFFE8B923),
                backgroundColor: Color(0xFF2A2A2A),
                onSelected: (selected) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                  _loadReportData();
                },
              );
            }).toList(),
          ),
          
          SizedBox(height: 12),
          
          // عرض الفترة المحددة
          Row(
            children: [
              Icon(Icons.calendar_today, color: Color(0xFFE8B923), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getPeriodDisplayText(),
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _getPeriodDisplayText() {
    final range = _getDateRangeForPeriod(_selectedPeriod);
    
    if (_selectedPeriod == 'اليوم') {
      return '${DateFormat('dd/MM/yyyy').format(range.start)} (اليوم)';
    } else if (_selectedPeriod == 'أمس') {
      return '${DateFormat('dd/MM/yyyy').format(range.start)} (أمس)';
    } else if (_selectedPeriod == 'مخصص') {
      return '${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}';
    } else {
      return '${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)} (${_selectedPeriod})';
    }
  }
  
  // 2. ملخص سريع
  Widget _buildQuickSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE8B923).withOpacity(0.1),
            Color(0xFF1A1A1A),
        ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE8B923).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            value: '${NumberFormat('#,##0').format(totalExpenses)} ج.م',
            label: 'إجمالي المصروفات',
            icon: Icons.account_balance_wallet,
            color: Colors.red,
          ),
          _buildSummaryItem(
            value: '$transactionsCount',
            label: 'عدد المعاملات',
            icon: Icons.list,
            color: Colors.blue,
          ),
          _buildSummaryItem(
            value: _selectedPeriod,
            label: 'الفترة المحددة',
            icon: Icons.calendar_today,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  // 3. محتوى التقرير حسب النوع
  Widget _buildReportByType() {
    switch (_selectedReportType) {
      case 'إحصائي':
        return _buildStatisticalReport();
      case 'تفصيلي':
        return _buildDetailedReport();
      case 'التصنيفات':
        return _buildCategoryReport();
      case 'المقارنة':
        return _buildComparisonReport();
      default:
        return _buildStatisticalReport();
    }
  }
  
  // 3.1 التقرير الإحصائي
  Widget _buildStatisticalReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التقرير الإحصائي',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildStatRow('إجمالي المصروفات', 
                '${NumberFormat('#,##0').format(totalExpenses)} ج.م'),
              SizedBox(height: 12),
              _buildStatRow('عدد المعاملات', '$transactionsCount عملية'),
              SizedBox(height: 12),
              _buildStatRow('متوسط المعاملة', 
                '${NumberFormat('#,##0').format(transactionsCount > 0 ? totalExpenses / transactionsCount : 0)} ج.م'),
              SizedBox(height: 12),
              _buildStatRow('الفترة الزمنية', _selectedPeriod),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  // 3.2 التقرير التفصيلي
  Widget _buildDetailedReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التقرير التفصيلي',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'قائمة بجميع المعاملات (${expenses.length})',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              
              if (expenses.isEmpty)
                Center(
                  child: Text(
                    'لا توجد معاملات في هذه الفترة',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                )
              else
                ...expenses.map((expense) {
                  final date = DateTime.parse(expense['ExpenseDate']);
                  final amount = expense['Amount'] as double;
                  final category = expense['CategoryName'] as String? ?? 'غير مصنف';
                  final notes = expense['Notes'] as String? ?? '';
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy - HH:mm').format(date),
                                style: GoogleFonts.cairo(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                category,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (notes.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  notes,
                                  style: GoogleFonts.cairo(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${NumberFormat('#,##0').format(amount)} ج.م',
                          style: GoogleFonts.cairo(
                            color: Color(0xFFE8B923),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 3.3 تقرير التصنيفات
  Widget _buildCategoryReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تقرير التصنيفات',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'سيتم إضافة تحليل التصنيفات قريباً',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
  
  // 3.4 تقرير المقارنة
  Widget _buildComparisonReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تقرير المقارنة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'سيتم إضافة المقارنة بين الفترات قريباً',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
  
  // === دوال المشاركة والتصدير ===
  
  void _shareReport() async {
    try {
      final reportContent = _generateShareableReport();
      await Share.share(
        reportContent,
        subject: 'تقرير مصروفات - ${widget.username}',
      );
    } catch (e) {
      print('❌ خطأ في المشاركة: $e');
      _showSnackbar('حدث خطأ في المشاركة');
    }
  }
  
  String _generateShareableReport() {
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    
    return '''
    📊 *تقرير المصروفات الشخصية*
    👤 المستخدم: ${widget.username}
    📅 تاريخ التقرير: $dateStr
    ⏰ الفترة: $_selectedReportType - $_selectedPeriod
    ═══════════════════════
    
    📈 *الإحصائيات:*
    • إجمالي المصروفات: ${NumberFormat('#,##0').format(totalExpenses)} ج.م
    • عدد المعاملات: $transactionsCount عملية
    • المتوسط لكل معاملة: ${NumberFormat('#,##0').format(transactionsCount > 0 ? totalExpenses / transactionsCount : 0)} ج.م
    
    📋 *ملخص الفترة:*
    ${_getPeriodDisplayText()}
    
    ═══════════════════════
    تم إنشاؤه تلقائياً عبر نظام إدارة المصروفات
    ''';
  }
  
  void _exportReport() {
    _showSnackbar('سيتم إضافة خيار التصدير قريباً');
  }
  
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 2),
      ),
    );
  }
}