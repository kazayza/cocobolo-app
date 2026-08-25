import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// ─────────────────────────────────────────────────────────────
///  AdminService — إدارة المستخدمين والصلاحيات
///  (يتواصل مع /api/admin/* في الباك اند)
/// ─────────────────────────────────────────────────────────────

class AdminUser {
  final int userId;
  final String username;
  final String fullName;
  final String? email;
  final String? role;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final int? employeeId;
  final String? employeeName;
  final int permissionsCount;

  const AdminUser({
    required this.userId,
    required this.username,
    required this.fullName,
    this.email,
    this.role,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.lastLogin,
    this.employeeId,
    this.employeeName,
    this.permissionsCount = 0,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      userId: json['userId'] ?? json['UserID'] ?? 0,
      username: json['username'] ?? json['Username'] ?? '',
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      email: json['email'] ?? json['Email'],
      role: json['role'] ?? json['Role'],
      isActive:
          (json['isActive'] ?? json['IsActive'] ?? true) == true ||
          (json['isActive'] ?? json['IsActive']) == 1,
      createdBy: json['createdBy'] ?? json['CreatedBy'],
      createdAt: AdminService._parseDate(
        json['createdAt'] ?? json['CreatedAt'],
      ),
      lastLogin: AdminService._parseDate(
        json['lastLogin'] ?? json['LastLogin'],
      ),
      employeeId: json['employeeId'] ?? json['employeeID'],
      employeeName: json['employeeName'] ?? json['EmployeeName'],
      permissionsCount: json['permissionsCount'] ?? 0,
    );
  }
}

class AdminPermission {
  final int permissionId;
  final String permissionName;
  final String? description;
  final String? category;
  final String? formName;

  const AdminPermission({
    required this.permissionId,
    required this.permissionName,
    this.description,
    this.category,
    this.formName,
  });

  factory AdminPermission.fromJson(Map<String, dynamic> json) {
    return AdminPermission(
      permissionId: json['permissionId'] ?? json['PermissionID'] ?? 0,
      permissionName: json['permissionName'] ?? json['PermissionName'] ?? '',
      description: json['description'] ?? json['Description'],
      category: json['category'] ?? json['Category'],
      formName: json['formName'] ?? json['FormName'],
    );
  }
}

class UserPermissionState {
  final int permissionId;
  bool canView;
  bool canAdd;
  bool canEdit;
  bool canDelete;

  UserPermissionState({
    required this.permissionId,
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  bool get isAnyEnabled => canView || canAdd || canEdit || canDelete;
}

class AdminService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  /// قائمة المستخدمين
  static Future<List<AdminUser>> getUsers() async {
    try {
      final token = await _getToken();
      final res = await http
          .get(Uri.parse('$baseUrl/api/admin/users'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is! Map || data['data'] is! List) return [];

      return (data['data'] as List)
          .whereType<Map>()
          .map((m) => AdminUser.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      print('❌ AdminService.getUsers: $e');
      return [];
    }
  }

  /// قائمة الموظفين النشطين (لربط المستخدم بموظف)
  static Future<List<Map<String, dynamic>>> getActiveEmployees() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/employees/active'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ AdminService.getActiveEmployees: $e');
      return [];
    }
  }

  /// كل صلاحيات النظام
  static Future<List<AdminPermission>> getPermissions() async {
    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/admin/permissions'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data is! Map || data['data'] is! List) return [];

      return (data['data'] as List)
          .whereType<Map>()
          .map((m) => AdminPermission.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      print('❌ AdminService.getPermissions: $e');
      return [];
    }
  }

  /// صلاحيات مستخدم معين (خريطة permissionId → state)
  static Future<Map<int, UserPermissionState>> getUserPermissions(
    int userId,
  ) async {
    try {
      final token = await _getToken();
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/admin/users/$userId/permissions'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body);
      if (data is! Map || data['data'] is! List) return {};

      final map = <int, UserPermissionState>{};
      for (final item in (data['data'] as List).whereType<Map>()) {
        final m = Map<String, dynamic>.from(item);
        map[m['permissionId']] = UserPermissionState(
          permissionId: m['permissionId'],
          canView: m['canView'] == true,
          canAdd: m['canAdd'] == true,
          canEdit: m['canEdit'] == true,
          canDelete: m['canDelete'] == true,
        );
      }
      return map;
    } catch (e) {
      print('❌ AdminService.getUserPermissions: $e');
      return {};
    }
  }

  /// إضافة مستخدم جديد
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String fullName,
    required String password,
    String? email,
    String? role,
    bool isActive = true,
    int? employeeId,
    String? createdBy,
  }) async {
    try {
      final token = await _getToken();
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/admin/users'),
            headers: _headers(token),
            body: jsonEncode({
              'username': username,
              'fullName': fullName,
              'password': password,
              'email': email,
              'role': role,
              'isActive': isActive,
              'employeeId': employeeId,
              'createdBy': createdBy,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 201 || res.statusCode == 200,
        'message': data['message'] ?? 'تمت العملية',
        'data': data['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// تعديل مستخدم
  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String fullName,
    String? password,
    String? email,
    String? role,
    bool? isActive,
    int? employeeId,
  }) async {
    try {
      final token = await _getToken();
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/admin/users/$userId'),
            headers: _headers(token),
            body: jsonEncode({
              'fullName': fullName,
              if (password != null && password.isNotEmpty) 'password': password,
              'email': email,
              'role': role,
              'isActive': isActive,
              'employeeId': employeeId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'تمت العملية',
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// حذف مستخدم
  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      final token = await _getToken();
      final res = await http
          .delete(
            Uri.parse('$baseUrl/api/admin/users/$userId'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'تم الحذف',
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  /// حفظ صلاحيات مستخدم
  static Future<Map<String, dynamic>> saveUserPermissions({
    required int userId,
    required List<UserPermissionState> permissions,
    String? assignedBy,
  }) async {
    try {
      final token = await _getToken();
      final res = await http
          .put(
            Uri.parse('$baseUrl/api/admin/users/$userId/permissions'),
            headers: _headers(token),
            body: jsonEncode({
              'permissions': [
                for (final p in permissions)
                  {
                    'permissionId': p.permissionId,
                    'canView': p.canView,
                    'canAdd': p.canAdd,
                    'canEdit': p.canEdit,
                    'canDelete': p.canDelete,
                  },
              ],
              'assignedBy': assignedBy,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'تم الحفظ',
      };
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }
}
