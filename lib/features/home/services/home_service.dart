import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../constants.dart';
import '../models/home_dashboard_model.dart';
import '../../../services/cashbox_service.dart';
import '../../../services/expense_service.dart';
import '../../../services/followups_service.dart';
import '../../../services/permission_service.dart';

class HomeService {
  final PermissionService permissions;

  HomeService({required this.permissions});

  /// تحميل البيانات الرئيسية للـ ERP Dashboard
  Future<HomeDashboardModel> loadDashboard({
    required int userId,
    required String username,
  }) async {
    final role = permissions.role ?? 'User';
    final employeeId = permissions.employeeId ?? 0;

    final uri = Uri.parse('$baseUrl/api/dashboard').replace(
      queryParameters: {
        'userId': userId.toString(),
        'username': username,
        'role': role,
        'employeeId': employeeId.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw HomeServiceException(
        'فشل تحميل بيانات لوحة التحكم',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const HomeServiceException('استجابة لوحة التحكم غير صالحة');
    }

    final data = Map<String, dynamic>.from(decoded);

    var dashboard = HomeDashboardModel.fromJson(data);

    // تحميل المهام
    final tasks = await loadUrgentTasks();

    // تحميل ملخص المتابعات
    final followUps = await loadFollowUpsSummary();

    // تحميل عدد العملاء
    final clientCount = await loadClientCount();

    // تحميل رصيد الخزينة + مصروفات الشهر (للكاروسيل المالي)
    final cashbox = await loadCashboxTotal();
    final monthExpenses = await loadMonthExpenses();

    final updatedSummary = <String, dynamic>{
      ...dashboard.summary,
      ...clientCount,
      ...followUps,
      ...cashbox,
      ...monthExpenses,
    };

    return dashboard.copyWith(
      summary: updatedSummary,
      urgentTasks: tasks,
      lastUpdated: DateTime.now(),
      isOffline: false,
    );
  }

  /// مهام اليوم / المهام العاجلة
  Future<List<HomeTaskModel>> loadUrgentTasks() async {
    if (!permissions.canView(FormNames.dailyTasks)) {
      return const [];
    }

    final employeeId = permissions.employeeId ?? 0;

    final uri = Uri.parse(
      '$baseUrl/api/tasks/today',
    ).replace(queryParameters: {'assignedTo': employeeId.toString()});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> rawTasks;

      if (decoded is Map && decoded['tasks'] is List) {
        rawTasks = decoded['tasks'] as List;
      } else if (decoded is List) {
        rawTasks = decoded;
      } else {
        return const [];
      }

      return rawTasks
          .whereType<Map>()
          .map(
            (item) => HomeTaskModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      // فشل المهام لا يجب أن يمنع الـDashboard بالكامل.
      return const [];
    }
  }

  /// ملخص المتابعات:
  /// Leads + Clients + Tasks
  Future<Map<String, dynamic>> loadFollowUpsSummary() async {
    if (!permissions.canView(FormNames.dailyTasks) &&
        !permissions.canView(FormNames.leadsCrm)) {
      return const {};
    }

    try {
      final bool mineOnly =
          !(permissions.isAdmin ||
              permissions.isSalesManager ||
              permissions.isGeneralManager);

      final summary = await FollowUpsService.getSummary(
        employeeId: mineOnly ? permissions.employeeId : null,
        source: 'all',
      );

      if (summary.isEmpty) {
        return const {};
      }

      return {
        'followUpsTotal': summary['total'] ?? 0,
        'followUpsOverdue': summary['overdue'] ?? 0,
        'followUpsToday': summary['today'] ?? 0,
        'followUpsTomorrow': summary['tomorrow'] ?? 0,
        'followUpsLeads': summary['leads'] ?? 0,
        'followUpsClients': summary['clients'] ?? 0,
        'tasksToday': summary['today'] ?? 0,
      };
    } catch (_) {
      return const {};
    }
  }

  /// عدد العملاء
  Future<Map<String, dynamic>> loadClientCount() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/clients/summary'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const {};
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return const {};
      }

      final data = Map<String, dynamic>.from(decoded);

      return {'totalClients': data['totalClients'] ?? 0};
    } catch (_) {
      return const {};
    }
  }

  /// رصيد الخزينة — مجموع أرصدة كل الخزائن
  Future<Map<String, dynamic>> loadCashboxTotal() async {
    if (!permissions.canView(FormNames.cashBoxDashboard)) {
      return const {};
    }

    try {
      final balances = await CashboxService.getCashboxBalances();
      if (balances.isEmpty) return const {};

      var total = 0.0;
      for (final b in balances) {
        total += (b['Balance'] ?? 0).toDouble();
      }

      return {'cashboxBalance': total, 'cashboxCount': balances.length};
    } catch (_) {
      return const {};
    }
  }

  /// مصروفات الشهر الحالي
  Future<Map<String, dynamic>> loadMonthExpenses() async {
    if (!permissions.canView(FormNames.expensesList)) {
      return const {};
    }

    try {
      final summary = await ExpenseService.getSummary();
      if (summary == null || summary.isEmpty) return const {};

      return {
        'monthExpenses': summary['monthAmount'] ?? 0,
        'todayExpenses': summary['todayAmount'] ?? 0,
        'expensesPrevMonth': summary['prevMonthAmount'] ?? 0,
      };
    } catch (_) {
      return const {};
    }
  }
}

class HomeServiceException implements Exception {
  final String message;
  final int? statusCode;

  const HomeServiceException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return '$message (HTTP $statusCode)';
    }

    return message;
  }
}
