import 'package:flutter/foundation.dart';

import '../models/home_dashboard_model.dart';
import '../services/home_service.dart';

class HomeProvider extends ChangeNotifier {
  final HomeService service;

  HomeProvider({
    required this.service,
  });

  HomeDashboardModel? _dashboard;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  bool _isOffline = false;

  String? _errorMessage;

  HomeDashboardModel? get dashboard => _dashboard;

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get hasError => _hasError;

  bool get isOffline => _isOffline;

  String? get errorMessage => _errorMessage;

  bool get hasData => _dashboard != null;

  /// البيانات الرئيسية
  Map<String, dynamic> get summary =>
      _dashboard?.summary ?? const {};

  /// المهام العاجلة
  List<HomeTaskModel> get urgentTasks =>
      _dashboard?.urgentTasks ?? const [];

  /// الأنشطة الأخيرة
  List<HomeActivityModel> get recentActivities =>
      _dashboard?.recentActivities ?? const [];

  /// عدد الإشعارات غير المقروءة
  int get unreadCount =>
      _dashboard?.unreadCount ?? 0;

  /// آخر تحديث
  DateTime? get lastUpdated =>
      _dashboard?.lastUpdated;

  /// تحميل الـDashboard لأول مرة
  Future<void> load({
    required int userId,
    required String username,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;

    notifyListeners();

    try {
      final result = await service.loadDashboard(
        userId: userId,
        username: username,
      );

      _dashboard = result;
      _isOffline = false;
      _hasError = false;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحديث يدوي للـDashboard
  Future<void> refresh({
    required int userId,
    required String username,
  }) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _hasError = false;
    _errorMessage = null;

    notifyListeners();

    try {
      final result = await service.loadDashboard(
        userId: userId,
        username: username,
      );

      _dashboard = result;
      _isOffline = false;
      _hasError = false;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();

      // لو عندنا بيانات قديمة، لا نمسحها.
      if (_dashboard != null) {
        _isOffline = true;
      }
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// إعادة المحاولة بعد الخطأ
  Future<void> retry({
    required int userId,
    required String username,
  }) async {
    await load(
      userId: userId,
      username: username,
    );
  }

  /// تحديث البيانات المحلية للـSummary
  void updateSummaryValue(
    String key,
    dynamic value,
  ) {
    if (_dashboard == null) return;

    final updatedSummary = {
      ..._dashboard!.summary,
      key: value,
    };

    _dashboard = _dashboard!.copyWith(
      summary: updatedSummary,
    );

    notifyListeners();
  }

  /// تحديث عدد الإشعارات
  void updateUnreadCount(int count) {
    if (_dashboard == null) return;

    _dashboard = _dashboard!.copyWith(
      unreadCount: count,
    );

    notifyListeners();
  }

  /// مسح الخطأ فقط
  void clearError() {
    if (!_hasError && _errorMessage == null) {
      return;
    }

    _hasError = false;
    _errorMessage = null;

    notifyListeners();
  }

  /// إعادة تعيين الـProvider
  void reset() {
    _dashboard = null;

    _isLoading = false;
    _isRefreshing = false;
    _hasError = false;
    _isOffline = false;

    _errorMessage = null;

    notifyListeners();
  }
}