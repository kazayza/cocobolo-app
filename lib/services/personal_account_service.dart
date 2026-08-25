import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// 👤 سيرفس الحسابات الشخصية (مطابق لموديول الـ API / بلازور)
class PersonalAccountService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// قائمة الحسابات (مع بحث + نوع + فلتر رصيد + صفحات)
  static Future<PersonalAccountsResult> getAccounts({
    String? search,
    String? accountType,
    String? balanceFilter,
    bool? isActive,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final q = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (search != null && search.trim().isNotEmpty) q['search'] = search.trim();
      if (accountType != null && accountType.isNotEmpty) q['accountType'] = accountType;
      if (balanceFilter != null && balanceFilter.isNotEmpty && balanceFilter != 'All') {
        q['balanceFilter'] = balanceFilter;
      }
      if (isActive != null) q['isActive'] = isActive.toString();

      final res = await http.get(_uri('/api/personal-accounts', q));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] is Map ? body['data'] : <String, dynamic>{};
        final items = (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
        return PersonalAccountsResult(
          items: items,
          total: (data['total'] as num?)?.toInt() ?? items.length,
          totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
          page: (data['page'] as num?)?.toInt() ?? page,
        );
      }
    } catch (e) {
      print('❌ PersonalAccountService.getAccounts: $e');
    }
    return PersonalAccountsResult.empty();
  }

  /// إحصائيات كل الحسابات (دائنون/مدينون/صافي)
  static Future<Map<String, dynamic>> getTotals() async {
    try {
      final res = await http.get(_uri('/api/personal-accounts/totals'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      print('❌ PersonalAccountService.getTotals: $e');
    }
    return {'TotalCreditors': 0, 'TotalDebtors': 0, 'Net': 0, 'NetLabel': 'عليكم'};
  }

  /// أنواع الحسابات
  static Future<List<Map<String, dynamic>>> getTypes() async {
    try {
      final res = await http.get(_uri('/api/personal-accounts/types'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is List) {
          return (body['data'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('❌ PersonalAccountService.getTypes: $e');
    }
    return const [];
  }

  /// حساب واحد
  static Future<Map<String, dynamic>?> getAccountById(int id) async {
    try {
      final res = await http.get(_uri('/api/personal-accounts/$id'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
    } catch (e) {
      print('❌ PersonalAccountService.getAccountById: $e');
    }
    return null;
  }

  /// كشف حساب (كل الحركات + رصيد جاري)
  static Future<PersonalAccountStatement?> getStatement(int accountId, {String? from, String? to}) async {
    try {
      final q = <String, String>{};
      if (from != null && from.isNotEmpty) q['from'] = from;
      if (to != null && to.isNotEmpty) q['to'] = to;

      final res = await http.get(
        _uri('/api/personal-accounts/$accountId/statement', q.isEmpty ? null : q),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is Map) {
          final d = Map<String, dynamic>.from(body['data'] as Map);
          final acc = d['Account'] is Map ? Map<String, dynamic>.from(d['Account'] as Map) : <String, dynamic>{};
          final txs = (d['Transactions'] as List? ?? []).cast<Map<String, dynamic>>();
          return PersonalAccountStatement(
            account: acc,
            transactions: txs,
            openingBalance: (d['OpeningBalanceAtStart'] as num?)?.toDouble() ?? 0,
            closingBalance: (d['ClosingBalanceAtEnd'] as num?)?.toDouble() ?? 0,
          );
        }
      }
    } catch (e) {
      print('❌ PersonalAccountService.getStatement: $e');
    }
    return null;
  }

  /// إنشاء حساب جديد
  static Future<Map<String, dynamic>> createAccount({
    required String accountName,
    String accountType = 'Other',
    String? phone,
    String? email,
    String? nationalId,
    String? notes,
    double openingBalance = 0,
    String? openingDate,
    String openingType = 'Credit',
    required String userName,
  }) async {
    try {
      final body = <String, dynamic>{
        'accountName': accountName,
        'accountType': accountType,
        'openingBalance': openingBalance,
        'openingType': openingType,
        'userName': userName,
      };
      if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone;
      if (email != null && email.trim().isNotEmpty) body['email'] = email;
      if (nationalId != null && nationalId.trim().isNotEmpty) body['nationalId'] = nationalId;
      if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes;
      if (openingDate != null) body['openingDate'] = openingDate;

      final res = await http.post(
        _uri('/api/personal-accounts'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': res.statusCode == 200};
    } catch (e) {
      print('❌ PersonalAccountService.createAccount: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// تعديل حساب
  static Future<Map<String, dynamic>> updateAccount({
    required int accountId,
    required String accountName,
    String accountType = 'Other',
    String? phone,
    String? email,
    String? nationalId,
    String? notes,
    double openingBalance = 0,
    String? openingDate,
    String openingType = 'Credit',
    bool isActive = true,
    required String userName,
  }) async {
    try {
      final body = <String, dynamic>{
        'accountName': accountName,
        'accountType': accountType,
        'openingBalance': openingBalance,
        'openingType': openingType,
        'isActive': isActive,
        'userName': userName,
      };
      if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone;
      if (email != null && email.trim().isNotEmpty) body['email'] = email;
      if (nationalId != null && nationalId.trim().isNotEmpty) body['nationalId'] = nationalId;
      if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes;
      if (openingDate != null) body['openingDate'] = openingDate;

      final res = await http.put(
        _uri('/api/personal-accounts/$accountId'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': res.statusCode == 200};
    } catch (e) {
      print('❌ PersonalAccountService.updateAccount: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// حذف / تعطيل حساب
  static Future<Map<String, dynamic>> deleteAccount(int accountId, {required String userName}) async {
    try {
      final res = await http.delete(
        _uri('/api/personal-accounts/$accountId'),
        headers: _jsonHeaders,
        body: jsonEncode({'userName': userName}),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': res.statusCode == 200};
    } catch (e) {
      print('❌ PersonalAccountService.deleteAccount: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// إضافة حركة (LoanIn = قرض دخل / LoanRepayment = تسديد)
  static Future<Map<String, dynamic>> createTransaction({
    required int accountId,
    required String operationType, // LoanIn / LoanRepayment
    required int cashBoxId,
    required double amount,
    DateTime? transactionDate,
    String? notes,
    required String userName,
  }) async {
    try {
      final body = <String, dynamic>{
        'operationType': operationType,
        'cashBoxId': cashBoxId,
        'amount': amount,
        'userName': userName,
      };
      if (transactionDate != null) body['transactionDate'] = transactionDate.toIso8601String();
      if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes;

      final res = await http.post(
        _uri('/api/personal-accounts/$accountId/transactions'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': res.statusCode == 200};
    } catch (e) {
      print('❌ PersonalAccountService.createTransaction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}

/// نتيجة قائمة الحسابات
class PersonalAccountsResult {
  final List<Map<String, dynamic>> items;
  final int total;
  final int totalPages;
  final int page;

  const PersonalAccountsResult({
    required this.items,
    required this.total,
    required this.totalPages,
    required this.page,
  });

  factory PersonalAccountsResult.empty() => const PersonalAccountsResult(
        items: [],
        total: 0,
        totalPages: 1,
        page: 1,
      );
}

/// كشف حساب
class PersonalAccountStatement {
  final Map<String, dynamic> account;
  final List<Map<String, dynamic>> transactions;
  final double openingBalance;
  final double closingBalance;

  const PersonalAccountStatement({
    required this.account,
    required this.transactions,
    required this.openingBalance,
    required this.closingBalance,
  });
}
