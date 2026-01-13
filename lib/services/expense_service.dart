import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../constants.dart';

class ExpenseService {
  // ==================== APIs موجودة بالفعل ====================
  
  // 1. جلب ملخص المصروفات (API موجودة)
  static Future<Map<String, dynamic>?> getSummary() async {
    try {
      print('📥 جاري تحميل ملخص المصروفات...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/expenses/summary'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        print('✅ تم تحميل ملخص المصروفات');
        return jsonDecode(response.body);
      } else {
        print('❌ خطأ في الملخص: ${response.statusCode}');
        print('📄 الاستجابة: ${response.body}');
        return null;
      }
    } catch (e) {
      print('🔥 خطأ في جلب الملخص: $e');
      return null;
    }
  }
  
  // 2. جلب الخزائن (API موجودة - تأكد من الاسم cashboxes)
  static Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      print('📥 جاري تحميل الخزائن...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/expenses/cashboxes'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ تم تحميل ${data.length} خزينة');
        
        return data.map((item) {
          return {
            'CashBoxID': item['CashBoxID'] ?? 0,
            'CashBoxName': item['CashBoxName'] ?? 'غير معروف',
          };
        }).toList();
      }
      print('❌ خطأ في الخزائن: ${response.statusCode}');
      return [];
    } catch (e) {
      print('🔥 خطأ في جلب الخزائن: $e');
      return [];
    }
  }
  
  // 3. جلب التصنيفات (API موجودة)
  static Future<List<Map<String, dynamic>>> getExpenseGroups() async {
    try {
      print('📥 جاري تحميل التصنيفات...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/expenses/groups'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ تم تحميل ${data.length} تصنيف');
        
        return data.map((item) {
          return {
            'ExpenseGroupID': item['ExpenseGroupID'] ?? 0,
            'ExpenseGroupName': item['ExpenseGroupName'] ?? 'غير معروف',
          };
        }).toList();
      }
      print('❌ خطأ في التصنيفات: ${response.statusCode}');
      return [];
    } catch (e) {
      print('🔥 خطأ في جلب التصنيفات: $e');
      return [];
    }
  }
  
  // 4. جلب المصروفات مع الفلترة (API موجودة)
  static Future<List<Map<String, dynamic>>> getExpenses({
    String? search,
    int? groupId,
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    try {
      print('📥 جاري تحميل المصروفات...');
      
      // بناء رابط البحث
      String url = '$baseUrl/api/expenses?';
      final params = <String>[];
      
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      if (groupId != null) {
        params.add('groupId=$groupId');
      }
      if (startDate != null) {
        params.add('startDate=$startDate');
      }
      if (endDate != null) {
        params.add('endDate=$endDate');
      }
      params.add('limit=$limit');
      
      url += params.join('&');
      print('🔗 الرابط: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('✅ تم تحميل ${data.length} مصروف');
        
        return data.map((item) {
          return {
            'ExpenseID': item['ExpenseID'] ?? 0,
            'ExpenseName': item['ExpenseName'] ?? '',
            'ExpenseDate': item['ExpenseDate'] ?? DateTime.now().toString(),
            'Amount': (item['Amount'] ?? 0).toDouble(),
            'ExpenseGroupName': item['ExpenseGroupName'] ?? 'غير مصنف',
            'CashBoxName': item['CashBoxName'] ?? 'غير معروف',
            'Notes': item['Notes'] ?? '',
            'Torecipient': item['Torecipient'] ?? '',
          };
        }).toList();
      }
      
      print('❌ خطأ في المصروفات: ${response.statusCode}');
      print('📄 الاستجابة: ${response.body}');
      return [];
    } catch (e) {
      print('🔥 خطأ في جلب المصروفات: $e');
      return [];
    }
  }
  
  // ==================== دوال جديدة للداشبورد ====================
  
  // 5. جلب المصروفات حسب الفترة للرسم البياني
  static Future<List<Map<String, dynamic>>> getExpensesForChart({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final start = DateFormat('yyyy-MM-dd').format(startDate);
      final end = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('📊 جاري تحميل بيانات الرسم البياني ($start إلى $end)...');
      
      return await getExpenses(
        startDate: start,
        endDate: end,
        limit: 500, // جلب كمية مناسبة للرسم البياني
      );
    } catch (e) {
      print('🔥 خطأ في بيانات الرسم البياني: $e');
      return [];
    }
  }
  
  // 6. جلب توزيع التصنيفات
  static Future<Map<String, double>> getCategoryDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String? startStr, endStr;
      
      if (startDate != null && endDate != null) {
        startStr = DateFormat('yyyy-MM-dd').format(startDate);
        endStr = DateFormat('yyyy-MM-dd').format(endDate);
      }
      
      final expenses = await getExpenses(
        startDate: startStr,
        endDate: endStr,
        limit: 1000,
      );
      
      final Map<String, double> distribution = {};
      
      for (var expense in expenses) {
        final category = expense['ExpenseGroupName'] as String;
        final amount = expense['Amount'] as double;
        
        distribution.update(
          category,
          (value) => value + amount,
          ifAbsent: () => amount,
        );
      }
      
      print('📈 تم تحليل توزيع ${distribution.length} تصنيف');
      return distribution;
    } catch (e) {
      print('🔥 خطأ في توزيع التصنيفات: $e');
      return {};
    }
  }
  
  // 7. جلب أعلى التصنيفات
  static Future<List<Map<String, dynamic>>> getTopCategories({
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String? startStr, endStr;
      
      if (startDate != null && endDate != null) {
        startStr = DateFormat('yyyy-MM-dd').format(startDate);
        endStr = DateFormat('yyyy-MM-dd').format(endDate);
      }
      
      final distribution = await getCategoryDistribution(
        startDate: startDate,
        endDate: endDate,
      );
      
      // تحويل الخريطة إلى قائمة وترتيب تنازلي
      final List<Map<String, dynamic>> topCategories = [];
      
      distribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(limit)
        .forEach((entry) {
          topCategories.add({
            'name': entry.key,
            'amount': entry.value,
          });
        });
      
      print('🏆 أعلى $limit تصنيفات تم تحليلها');
      return topCategories;
    } catch (e) {
      print('🔥 خطأ في أعلى التصنيفات: $e');
      return [];
    }
  }
  
  // 8. جلب بيانات المقارنة بين فترتين
  static Future<Map<String, dynamic>> getComparisonData({
    DateTime? currentStart,
    DateTime? currentEnd,
    DateTime? previousStart,
    DateTime? previousEnd,
  }) async {
    try {
      // إذا لم يتم تحديد التواريخ، نستخدم الشهر الحالي والسابق
      final now = DateTime.now();
      
      final currentS = currentStart ?? DateTime(now.year, now.month, 1);
      final currentE = currentEnd ?? now;
      
      final previousS = previousStart ?? 
          DateTime(now.year, now.month - 1, 1);
      final previousE = previousEnd ?? 
          DateTime(now.year, now.month, 0);
      
      print('📊 جاري مقارنة الفترات...');
      print('   الفترة الحالية: $currentS إلى $currentE');
      print('   الفترة السابقة: $previousS إلى $previousE');
      
      // جلب بيانات الفترة الحالية
      final currentExpenses = await getExpensesForChart(
        startDate: currentS,
        endDate: currentE,
      );
      
      // جلب بيانات الفترة السابقة
      final previousExpenses = await getExpensesForChart(
        startDate: previousS,
        endDate: previousE,
      );
      
      // حساب الإجماليات
      final double currentTotal = currentExpenses.fold(0.0, 
          (sum, expense) => sum + (expense['Amount'] as double));
      
      final double previousTotal = previousExpenses.fold(0.0,
          (sum, expense) => sum + (expense['Amount'] as double));
      
      // حساب نسبة التغير
      double changePercent = 0;
      if (previousTotal > 0) {
        changePercent = ((currentTotal - previousTotal) / previousTotal) * 100;
      } else if (currentTotal > 0) {
        changePercent = 100; // إذا لم يكن هناك بيانات سابقة
      }
      
      print('📈 نتيجة المقارنة:');
      print('   الحالي: ${currentTotal.toStringAsFixed(2)}');
      print('   السابق: ${previousTotal.toStringAsFixed(2)}');
      print('   التغير: ${changePercent.toStringAsFixed(1)}%');
      
      return {
        'currentTotal': currentTotal,
        'previousTotal': previousTotal,
        'changePercent': changePercent,
        'isPositive': changePercent >= 0,
        'currentPeriod': '${DateFormat('dd/MM').format(currentS)}-${DateFormat('dd/MM').format(currentE)}',
        'previousPeriod': '${DateFormat('dd/MM').format(previousS)}-${DateFormat('dd/MM').format(previousE)}',
      };
      
    } catch (e) {
      print('🔥 خطأ في بيانات المقارنة: $e');
      return {
        'currentTotal': 0.0,
        'previousTotal': 0.0,
        'changePercent': 0.0,
        'isPositive': true,
        'currentPeriod': 'فترة حالية',
        'previousPeriod': 'فترة سابقة',
      };
    }
  }
  
  // 9. جلب بيانات الأسبوع الماضي (للمخطط الخطي)
  static Future<List<Map<String, double>>> getWeeklyData() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));
      
      final expenses = await getExpensesForChart(
        startDate: weekAgo,
        endDate: now,
      );
      
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
      
      // تحويل إلى قائمة مرتبة
      final List<Map<String, double>> weeklyData = [];
      
      for (int i = 0; i < 7; i++) {
        final date = weekAgo.add(Duration(days: i));
        final dayTotal = dailyTotals[date.day] ?? 0.0;
        
        weeklyData.add({
          'day': i.toDouble(),
          'amount': dayTotal,
        });
      }
      
      print('📅 بيانات أسبوعية جاهزة (${weeklyData.length} يوم)');
      return weeklyData;
    } catch (e) {
      print('🔥 خطأ في البيانات الأسبوعية: $e');
      return [];
    }
  }
  
  // 10. التحقق من اتصال API
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/expenses/groups'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ فشل الاتصال بالخادم: $e');
      return false;
    }
  }
}