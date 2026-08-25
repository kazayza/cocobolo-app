import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/expense_service.dart';
import '../../constants.dart';
import '../add_expense_screen.dart';

class FinancialDashboard extends StatefulWidget {
  final int userId;
  final String username;

  const FinancialDashboard({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<FinancialDashboard> createState() => _FinancialDashboardState();
}

class _FinancialDashboardState extends State<FinancialDashboard> {
  // البيانات
  double totalExpenses = 0.0;
  double todayExpenses = 0.0;
  double yesterdayExpenses = 0.0;
  double monthlyExpenses = 0.0;
  int cashBoxCount = 0;
  bool isLoading = true;
  
  // البيانات حسب الفترة المحددة
  double periodTotalExpenses = 0.0;
  List<Map<String, dynamic>> periodExpenses = [];
  
  // الفلاتر
  DateTimeRange? _selectedDateRange;
  String _selectedPeriod = 'هذا الشهر';
  List<String> periods = ['اليوم', 'أمس', 'الأسبوع', 'هذا الشهر', 'الشهر الماضي', 'مخصص'];
  
  // بيانات الرسوم البيانية
  List<FlSpot> weeklyExpenses = [];
  List<PieChartSectionData> categoryDistribution = [];
  List<String> categoryNames = []; // لأسماء التصنيفات
  
  // أعلى التصنيفات
  List<Map<String, dynamic>> topCategories = [];
  
  // بيانات المقارنة
  Map<String, dynamic> comparisonData = {};
  
  @override
  void initState() {
    super.initState();
    _initDateRange();
    loadDashboardData();
  }
  
  // تهيئة الفترة الافتراضية
  void _initDateRange() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    _selectedDateRange = DateTimeRange(start: startDate, end: now);
  }
  
  // تحميل البيانات مع الفلاتر
  // تحميل البيانات مع الفلاتر
Future<void> loadDashboardData() async {
  setState(() => isLoading = true);
  
  try {
    print('🚀 بدء تحميل بيانات الداشبورد...');
    
    // تطبيق الفلترة بناء على الفترة المحددة
    DateTimeRange dateRange = _getDateRangeForPeriod(_selectedPeriod);
    
    // 1. جلب ملخص المصروفات (كل الوقت)
    final summary = await ExpenseService.getSummary();
    if (summary != null) {
      totalExpenses = (summary['totalAmount'] ?? 0).toDouble();
      todayExpenses = (summary['todayAmount'] ?? 0).toDouble();
      monthlyExpenses = (summary['monthAmount'] ?? 0).toDouble();
      
      print('📊 الملخص: الإجمالي: $totalExpenses, اليوم: $todayExpenses, الشهر: $monthlyExpenses');
    }
    
    // 2. جلب عدد الخزائن
    final cashBoxes = await ExpenseService.getCashBoxes();
    cashBoxCount = cashBoxes.length;
    print('💰 عدد الخزائن: $cashBoxCount');
    
    // 3. جلب بيانات الفترة المحددة ← استخدمنا الدالة الموجودة
    final periodData = await ExpenseService.getExpensesForChart(
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
    
    // استخدم periodData مباشرة كمصروفات الفترة
    periodExpenses = periodData;
    
    // حساب إجمالي الفترة المحددة
    periodTotalExpenses = periodExpenses.fold(0.0, (sum, expense) {
      return sum + (expense['Amount'] as double);
    });
    print('📅 إجمالي الفترة المحددة: $periodTotalExpenses');
    
    // 4. جلب بيانات المقارنة مع الفترة السابقة
    comparisonData = await _getComparisonData();
    yesterdayExpenses = comparisonData['previousTotal'] ?? 0.0;
    
    // تحويل بيانات الفترة لنقاط الرسم البياني
    weeklyExpenses = _convertToChartData(periodData, dateRange);
    print('📈 بيانات الرسم البياني جاهزة (${weeklyExpenses.length} نقطة)');
    
    // 5. جلب توزيع التصنيفات للفترة المحددة
    final distribution = await ExpenseService.getCategoryDistribution(
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
    
    // تحويل التوزيع لمخطط دائري مع الأسماء
    final distributionResult = _convertDistributionToPieChart(distribution);
    categoryDistribution = distributionResult['sections'];
    categoryNames = distributionResult['names'];
    print('📊 توزيع ${categoryDistribution.length} تصنيف');
    
    // 6. جلب أعلى التصنيفات للفترة المحددة
    topCategories = await ExpenseService.getTopCategories(
      limit: 5,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );
    
    print('🏆 أعلى ${topCategories.length} تصنيفات');
    
    print('✅ تم تحميل جميع بيانات الداشبورد بنجاح');
    
  } catch (e) {
    print('❌ خطأ في تحميل البيانات: $e');
    
    // عرض رسالة خطأ للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فشل تحميل البيانات', style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => isLoading = false);
  }
}
  
  // تحديد الفترة الزمنية بناء على الاختيار
  // تحديد الفترة الزمنية بناء على الاختيار
DateTimeRange _getDateRangeForPeriod(String period) {
  final now = DateTime.now();
  
  switch (period) {
    case 'اليوم':
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
      
    case 'أمس':
      final yesterday = now.subtract(Duration(days: 1));
      final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
      
    case 'الأسبوع':
      final weekAgo = now.subtract(Duration(days: 7));
      return DateTimeRange(start: weekAgo, end: now);
      
    case 'هذا الشهر':
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59); // آخر يوم في الشهر
      return DateTimeRange(start: start, end: end);
      
    case 'الشهر الماضي':
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return DateTimeRange(start: lastMonth, end: end);
      
    case 'مخصص':
      return _selectedDateRange ?? DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      
    default:
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
  }
}
  
  // جلب بيانات المقارنة
  Future<Map<String, dynamic>> _getComparisonData() async {
    final currentRange = _getDateRangeForPeriod(_selectedPeriod);
    
    // تحديد الفترة السابقة بناء على الفترة الحالية
    DateTimeRange previousRange;
    
    if (_selectedPeriod == 'هذا الشهر') {
      final now = DateTime.now();
      previousRange = DateTimeRange(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
      );
    } else if (_selectedPeriod == 'الأسبوع') {
      final weekAgo = DateTime.now().subtract(Duration(days: 14));
      final twoWeeksAgo = DateTime.now().subtract(Duration(days: 21));
      previousRange = DateTimeRange(start: twoWeeksAgo, end: weekAgo);
    } else {
      // لكل حالة أخرى، نستخدم نفس المنطق
      final duration = currentRange.end.difference(currentRange.start);
      previousRange = DateTimeRange(
        start: currentRange.start.subtract(duration),
        end: currentRange.end.subtract(duration),
      );
    }
    
    return await ExpenseService.getComparisonData(
      currentStart: currentRange.start,
      currentEnd: currentRange.end,
      previousStart: previousRange.start,
      previousEnd: previousRange.end,
    );
  }
  
  // تحويل البيانات لنقاط الرسم البياني
  List<FlSpot> _convertToChartData(List<Map<String, dynamic>> expenses, DateTimeRange dateRange) {
    if (expenses.isEmpty) {
      // إذا لا توجد بيانات، نعود بنقاط افتراضية
      return List.generate(7, (index) => FlSpot(index.toDouble(), 0));
    }
    
    // تجميع البيانات حسب اليوم
    final Map<int, double> dailyTotals = {};
    
    for (var expense in expenses) {
      final date = DateTime.parse(expense['ExpenseDate']);
      final day = date.day;
      final amount = expense['Amount'] as double;
      
      dailyTotals.update(
        day,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    
    // تحويل إلى نقاط الرسم البياني
    final List<FlSpot> spots = [];
    final daysDiff = dateRange.end.difference(dateRange.start).inDays + 1;
    
    for (int i = 0; i < daysDiff; i++) {
      final date = dateRange.start.add(Duration(days: i));
      final dayTotal = dailyTotals[date.day] ?? 0.0;
      
      spots.add(FlSpot(i.toDouble(), dayTotal));
    }
    
    return spots;
  }
  
  // تحويل توزيع التصنيفات لمخطط دائري مع الأسماء
  Map<String, dynamic> _convertDistributionToPieChart(Map<String, double> distribution) {
    final List<PieChartSectionData> sections = [];
    final List<String> names = [];
    final List<Color> colors = [
      Color(0xFFE8B923),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFFFF5722),
      Color(0xFF00BCD4),
      Color(0xFFF44336),
      Color(0xFF3F51B5),
    ];
    
    double total = distribution.values.fold(0.0, (sum, amount) => sum + amount);
    
    if (total == 0) {
      // إذا لا توجد بيانات، نعرض رسالة
      sections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'لا توجد بيانات',
          radius: 60,
          titleStyle: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      names.add('لا توجد بيانات');
      return {'sections': sections, 'names': names};
    }
    
    int colorIndex = 0;
    distribution.entries.forEach((entry) {
      final percentage = (entry.value / total * 100);
      
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: entry.value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      
      names.add(entry.key);
      colorIndex++;
    });
    
    return {'sections': sections, 'names': names};
  }
  
  // اختيار فترة تاريخ مخصصة
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFFE8B923),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
            ),
            dialogBackgroundColor: Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedPeriod = 'مخصص';
      });
      
      // إعادة تحميل البيانات بالفترة الجديدة
      loadDashboardData();
    }
  }
  
  // تطبيق الفلترة
  void _applyFilter(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    
    // إعادة تحميل البيانات
    loadDashboardData();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'لوحة التحكم المالية',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color(0xFFE8B923),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: loadDashboardData,
          ),
        ],
      ),
      body: isLoading 
          ? _buildLoading()
          : _buildDashboardContent(),
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
            'جاري تحميل البيانات...',
            style: GoogleFonts.cairo(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== 1. فلاتر الفترة الزمنية =====
            _buildPeriodFilter(),
            SizedBox(height: 20),
            
            // ===== 2. الموجز اليومي =====
            _buildDailyBrief(),
            SizedBox(height: 20),
            
            // ===== 3. الإحصائيات السريعة =====
            _buildQuickStats(),
            SizedBox(height: 20),
            
            // ===== 4. الإجراءات السريعة =====
            _buildQuickActions(),
            SizedBox(height: 20),
            
            // ===== 5. مقارنة مع الفترة السابقة =====
            _buildComparisonSection(),
            SizedBox(height: 20),
            
            // ===== 6. الرسوم البيانية =====
            _buildChartsSection(),
            SizedBox(height: 20),
            
            // ===== 7. التصنيفات الأعلى =====
            _buildTopCategories(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  // 1. فلاتر الفترة الزمنية
  Widget _buildPeriodFilter() {
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
                'الفترة الزمنية',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedPeriod == 'مخصص' && _selectedDateRange != null)
                InkWell(
                  onTap: () => _selectDateRange(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFE8B923).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 14, color: Color(0xFFE8B923)),
                        SizedBox(width: 4),
                        Text(
                          'تعديل',
                          style: GoogleFonts.cairo(
                            color: Color(0xFFE8B923),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          
          // أزرار الفترات
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
                  if (period == 'مخصص') {
                    _selectDateRange(context);
                  } else {
                    _applyFilter(period);
                  }
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
  
  // 2. الموجز اليومي
  // 2. الموجز اليومي (الإحصائيات الفعلية)
Widget _buildDailyBrief() {
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
  
  // حساب مصروفات اليوم
  double todayTotal = 0.0;
  int todayTransactions = 0;
  
  for (var expense in periodExpenses) {
    final date = DateTime.parse(expense['ExpenseDate']);
    if (date.isAfter(todayStart) && date.isBefore(todayEnd)) {
      todayTotal += (expense['Amount'] as double);
      todayTransactions++;
    }
  }
  
  // اختيار الرسالة المناسبة
  String message = '';
  if (todayTotal == 0 && todayTransactions == 0) {
    message = ' ممتاز! ما أنفقتش ولا جنيه اليوم';
  } else if (todayTotal < 50) {
    message = '👍 إنفاق معتدل اليوم. استمر في التحكم بمصروفاتك';
  } else if (todayTotal < 200) {
    message = '💸 إنفاق اليوم متوسط. راقب مصروفاتك';
  } else {
    message = '⚠️ إنفاق اليوم مرتفع. حاول التوفير غداً';
  }
  
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
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'موجز اليوم',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getArabicDate(),
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // إحصائيات اليوم الفعلية
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '${NumberFormat('#,##0').format(todayTotal)}',
                  style: GoogleFonts.cairo(
                    color: todayTotal == 0 ? Colors.green : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إجمالي اليوم',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            
            Column(
              children: [
                Text(
                  '$todayTransactions',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'عدد المعاملات',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            
            Column(
              children: [
                Text(
                  todayTransactions > 0 
                    ? '${NumberFormat('#,##0').format(todayTotal / todayTransactions)}' 
                    : '0',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'متوسط المعاملة',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        
        SizedBox(height: 12),
        Divider(color: Colors.grey[700], height: 1),
        SizedBox(height: 12),
        
        // رسالة مخصصة بناءً على الإنفاق
        Text(
          message,
          style: GoogleFonts.cairo(
            color: Colors.grey[300],
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
  
  String _getArabicDate() {
    final now = DateTime.now();
    
    final days = [
      'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 
      'الخميس', 'الجمعة', 'السبت'
    ];
    
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    
    return '$dayName، ${now.day} $monthName';
  }
  
  String _getFinancialTip() {
    final tips = [
      '💡 حاول توفير 20% من دخلك كل شهر',
      '📊 تتبع مصروفاتك الصغيرة، فهي تتراكم',
      '📅 خطط لميزانيتك قبل بداية الشهر',
      '🎯 استخدم القاعدة 50/30/20 للتوزيع المالي',
      '🚫 تجنب الديون غير الضرورية',
      '💰 استثمر في تعليمك لتحسين دخلك',
      '🛒 تسوق بذكاء واحرص على العروض',
      '💳 استخدم البطاقات الائتمانية بحكمة',
    ];
    return tips[DateTime.now().day % tips.length];
  }
  
  // 3. الإحصائيات السريعة - معدلة لعرض إجمالي الفترة
// 3. الإحصائيات السريعة - معدلة
// 3. الإحصائيات السريعة - معدلة مع أعلى تصنيف
Widget _buildQuickStats() {
  // حساب مصروفات اليوم
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
  
  double todayTotal = 0.0;
  int todayTransactions = 0;
  
  for (var expense in periodExpenses) {
    final date = DateTime.parse(expense['ExpenseDate']);
    if (date.isAfter(todayStart) && date.isBefore(todayEnd)) {
      todayTotal += (expense['Amount'] as double);
      todayTransactions++;
    }
  }
  
  // حساب متوسط المصروفات اليومية للفترة المحددة
  final daysInPeriod = _getDateRangeForPeriod(_selectedPeriod).duration.inDays + 1;
  final avgDailyExpense = periodTotalExpenses / daysInPeriod;
  
  // أعلى تصنيف
  final topCategory = topCategories.isNotEmpty ? topCategories[0] : null;
  final topCategoryName = topCategory?['name'] ?? 'لا توجد';
  final topCategoryAmount = topCategory?['amount'] ?? 0.0;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'الإحصائيات السريعة',
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 12),
      
      GridView(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        children: [
          _buildStatCard(
            title: 'إجمالي الفترة',
            value: periodTotalExpenses,
            icon: Icons.account_balance_wallet,
            color: Colors.red,
            subtitle: _selectedPeriod,
            isTotal: true,
          ),
          
          _buildStatCard(
            title: 'مصروفات اليوم',
            value: todayTotal,
            icon: Icons.today,
            color: todayTotal > 0 ? Colors.orange : Colors.green,
            subtitle: 'اليوم',
          ),
          
          _buildStatCard(
            title: 'أعلى تصنيف',
            value: topCategoryAmount,
            icon: Icons.star,
            color: Colors.blue,
            subtitle: topCategoryName,
          ),
          
          _buildStatCard(
            title: 'عدد المعاملات',
            value: periodExpenses.length,
            icon: Icons.list,
            color: Colors.green,
            subtitle: 'عملية',
          ),
        ],
      ),
    ],
  );
}
  
  Widget _buildStatCard({
  required String title,
  required dynamic value,
  required IconData icon,
  required Color color,
  String? subtitle,
  bool isTotal = false,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (isTotal)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8B923).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedPeriod,
                    style: GoogleFonts.cairo(
                      color: Color(0xFFE8B923),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // إذا كان الرقم (مصاريف) يظهر بـ "ج.م"، وإلا رقم عادي
                value is num && (title.contains('مصروف') || title.contains('إجمالي') || title.contains('تصنيف'))
                    ? '${NumberFormat('#,##0').format(value)} ج.م'
                    : value is num 
                        ? '${NumberFormat('#,##0').format(value)}'
                        : '$value',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
  
  // 4. الإجراءات السريعة
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الإجراءات السريعة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        GridView(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            _buildActionButton(
              icon: Icons.add,
              label: 'إضافة مصروف',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(username: widget.username),
                  ),
                );
              },
            ),
            
            _buildActionButton(
              icon: Icons.download,
              label: 'تصدير تقرير',
              color: Colors.purple,
              onTap: _exportReport,
            ),
            
            _buildActionButton(
              icon: Icons.share,
              label: 'مشاركة',
              color: Colors.teal,
              onTap: _shareReport,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  // 5. مقارنة مع الفترة السابقة - معدلة
  // في _buildComparisonSection()، بداية الدالة:
Widget _buildComparisonSection() {
  final currentTotal = periodTotalExpenses;
  final previousTotal = yesterdayExpenses;
  
  // حساب نسبة التغير
  double changePercent = 0.0;
  bool isGoodChange = true; // هل التغير جيد؟ (انخفاض = جيد)
  
  if (previousTotal > 0) {
    changePercent = ((currentTotal - previousTotal) / previousTotal * 100);
    // هنا الفرق: انخفاض المصروفات (سالب) = جيد
    isGoodChange = currentTotal <= previousTotal;
  } else if (currentTotal > 0) {
    changePercent = 100.0;
    isGoodChange = false; // زيادة من صفر = مش جيد
  }
  
  // احسب الفرق المطلق
  final difference = (currentTotal - previousTotal);
  
  // علامة الفرق (+ أو -)
  final sign = difference >= 0 ? '+' : '-';
  final absoluteDifference = difference.abs();
  
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
              'مقارنة مع الفترة السابقة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isGoodChange 
                    ? Colors.green.withOpacity(0.2)  // انخفاض = جيد = أخضر
                    : Colors.red.withOpacity(0.2),   // زيادة = سيء = أحمر
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    isGoodChange ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 14,
                    color: isGoodChange ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${sign}${changePercent.abs().toStringAsFixed(1)}%',
                    style: GoogleFonts.cairo(
                      color: isGoodChange ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        // مقارنة مباشرة
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'الفترة الحالية',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##0').format(currentTotal)} ج.م',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                Column(
                  children: [
                    Text(
                      'الفرق',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${sign}${NumberFormat('#,##0').format(absoluteDifference)} ج.م',
                      style: GoogleFonts.cairo(
                        color: isGoodChange ? Colors.green : Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                Column(
                  children: [
                    Text(
                      'الفترة السابقة',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${NumberFormat('#,##0').format(previousTotal)} ج.م',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            
            Divider(color: Colors.grey[700]),
            SizedBox(height: 8),
            
            // ملخص التغير
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isGoodChange ? Icons.trending_down : Icons.trending_up,
                  color: isGoodChange ? Colors.green : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: isGoodChange ? 'انخفاض ' : 'زيادة ',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: 'بمقدار ${NumberFormat('#,##0').format(absoluteDifference)} ج.م ',
                        style: GoogleFonts.cairo(
                          color: isGoodChange ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '(${sign}${changePercent.abs().toStringAsFixed(1)}%)',
                        style: GoogleFonts.cairo(
                          color: isGoodChange ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      return '${_formatDate(range.start)} (اليوم)';
    } else if (_selectedPeriod == 'أمس') {
      return '${_formatDate(range.start)} (أمس)';
    } else if (_selectedPeriod == 'مخصص') {
      return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
    } else {
      return '${_formatDate(range.start)} - ${_formatDate(range.end)} (${_selectedPeriod})';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // 6. الرسوم البيانية - معدلة لعرض أسماء التصنيفات
  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التحليلات البيانية',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        
        // مخطط المصروفات حسب الفترة
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تطور المصروفات',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFE8B923).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedPeriod,
                      style: GoogleFonts.cairo(
                        color: Color(0xFFE8B923),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getMaxY() / 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[800]!,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: weeklyExpenses.isEmpty ? 6 : weeklyExpenses.last.x,
                    minY: 0,
                    maxY: _getMaxY() * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: weeklyExpenses,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE8B923).withOpacity(0.8),
                            Color(0xFFE8B923).withOpacity(0.2),
                        ],
                        ),
                        barWidth: 3,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE8B923).withOpacity(0.3),
                              Color(0xFFE8B923).withOpacity(0.1),
                            ],
                          ),
                        ),
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Center(
                child: Text(
                  'إجمالي المصروفات خلال الفترة',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 12),
        
        // مخطط توزيع التصنيفات مع الأسماء
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'توزيع المصروفات حسب التصنيف',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${categoryDistribution.length} تصنيف',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              if (categoryDistribution.length > 1)
                Column(
                  children: [
                    Container(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: categoryDistribution,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildCategoryLegendWithNames(),
                  ],
                )
              else
                Center(
                  child: Text(
                    'لا توجد بيانات كافية لعرض التوزيع',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  double _getMaxY() {
    if (weeklyExpenses.isEmpty) return 1000;
    double maxY = weeklyExpenses.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    return maxY > 0 ? maxY : 1000;
  }
  
  // مفتاح الألوان مع الأسماء والمبالغ
  Widget _buildCategoryLegendWithNames() {
    return Column(
      children: categoryDistribution.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        final categoryName = index < categoryNames.length ? categoryNames[index] : 'تصنيف ${index + 1}';
        
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: section.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoryName,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${NumberFormat('#,##0').format(section.value)} ج.م',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${(section.value / periodTotalExpenses * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.cairo(
                  color: Color(0xFFE8B923),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  // 7. التصنيفات الأعلى
  Widget _buildTopCategories() {
    if (topCategories.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'لا توجد بيانات للتصنيفات',
            style: GoogleFonts.cairo(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'أعلى التصنيفات إنفاقاً',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'للحساب الدقيق',
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: topCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final name = category['name'] as String;
              final amount = category['amount'] as double;
              final color = _getCategoryColor(index);
              
              return _buildCategoryItem(name, amount, color, index);
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Color _getCategoryColor(int index) {
    final colors = [
      Color(0xFFE8B923),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFFFF5722),
    ];
    return colors[index % colors.length];
  }
  
  Widget _buildCategoryItem(String name, double amount, Color color, int index) {
    // حساب النسبة المئوية من إجمالي الفترة
    final percentage = periodTotalExpenses > 0 ? (amount / periodTotalExpenses * 100) : 0;
    
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0').format(amount)} ج.م',
                      style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[800],
                  color: color,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}% من الإجمالي',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ==================== دوال المساعدة ====================
  
  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم إضافة خيار التصدير قريباً',
          style: GoogleFonts.cairo(),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _shareReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('سيتم إضافة خيار المشاركة قريباً', style: GoogleFonts.cairo()),
        duration: Duration(seconds: 2),
      ),
    );
  }
}