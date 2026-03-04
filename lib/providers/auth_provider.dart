import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  // بيانات المستخدم
  int? _userId;
  String? _username;
  String? _fullName;
  String? _email;
  int? _employeeId;
  String? _role;
  String? _token;

  // Getters
  int? get userId => _userId;
  String? get username => _username;
  String? get fullName => _fullName;
  String? get email => _email;
  int? get employeeId => _employeeId;
  String? get role => _role;
  String? get token => _token;

  // حالة تسجيل الدخول
  bool get isLoggedIn => _token != null && _userId != null;

  // التحقق من الأدوار
  bool get isAdmin => _role?.toLowerCase() == 'admin';
  bool get isSalesManager => _role?.toLowerCase() == 'salesmanager';
  bool get isAccountManager => _role?.toLowerCase() == 'accountmanager';
  bool get isSales => _role?.toLowerCase() == 'sales';
  bool get isAccount => _role?.toLowerCase() == 'account';

  // تسجيل الدخول
  void login({
    required int userId,
    required String username,
    String? fullName,
    String? email,
    int? employeeId,
    String? role,
    required String token,
  }) {
    _userId = userId;
    _username = username;
    _fullName = fullName;
    _email = email;
    _employeeId = employeeId;
    _role = role;
    _token = token;
    
    notifyListeners();
  }

  // تحديث البيانات
  void updateUser({
    String? fullName,
    String? email,
    String? role,
  }) {
    _fullName = fullName ?? _fullName;
    _email = email ?? _email;
    _role = role ?? _role;
    
    notifyListeners();
  }

  // تسجيل الخروج
  void logout() {
    _userId = null;
    _username = null;
    _fullName = null;
    _email = null;
    _employeeId = null;
    _role = null;
    _token = null;
    
    notifyListeners();
  }

  // مسح البيانات (نفس logout)
  void clear() => logout();
}