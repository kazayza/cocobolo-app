class HomeDashboardModel {
  final Map<String, dynamic> summary;
  final List<HomeTaskModel> urgentTasks;
  final List<HomeActivityModel> recentActivities;
  final int unreadCount;
  final DateTime? lastUpdated;
  final bool isOffline;

  const HomeDashboardModel({
    this.summary = const {},
    this.urgentTasks = const [],
    this.recentActivities = const [],
    this.unreadCount = 0,
    this.lastUpdated,
    this.isOffline = false,
  });

  factory HomeDashboardModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawSummary = json['summary'];

    final summary = rawSummary is Map
        ? Map<String, dynamic>.from(rawSummary)
        : <String, dynamic>{};

    final rawTasks = json['urgentTasks'] ??
        json['tasks'] ??
        const [];

    final urgentTasks = rawTasks is List
        ? rawTasks
            .whereType<Map>()
            .map(
              (item) => HomeTaskModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <HomeTaskModel>[];

    final rawActivities =
        json['recentActivities'] ??
        json['activities'] ??
        const [];

    final recentActivities = rawActivities is List
        ? rawActivities
            .whereType<Map>()
            .map(
              (item) => HomeActivityModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <HomeActivityModel>[];

    final unreadValue =
        json['unreadCount'] ??
        json['unreadNotifications'] ??
        0;

    return HomeDashboardModel(
      summary: summary,
      urgentTasks: urgentTasks,
      recentActivities: recentActivities,
      unreadCount: _toInt(unreadValue),
      lastUpdated: _parseDate(
        json['lastUpdated'],
      ),
      isOffline:
          json['isOffline'] == true,
    );
  }

  HomeDashboardModel copyWith({
    Map<String, dynamic>? summary,
    List<HomeTaskModel>? urgentTasks,
    List<HomeActivityModel>? recentActivities,
    int? unreadCount,
    DateTime? lastUpdated,
    bool? isOffline,
  }) {
    return HomeDashboardModel(
      summary: summary ?? this.summary,
      urgentTasks:
          urgentTasks ?? this.urgentTasks,
      recentActivities:
          recentActivities ??
              this.recentActivities,
      unreadCount:
          unreadCount ?? this.unreadCount,
      lastUpdated:
          lastUpdated ?? this.lastUpdated,
      isOffline:
          isOffline ?? this.isOffline,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}


// ============================================================
// مهام الـDashboard
// ============================================================

class HomeTaskModel {
  final int? id;
  final String title;
  final String? description;
  final String? priority;
  final bool isCompleted;
  final DateTime? dueDate;

  const HomeTaskModel({
    this.id,
    required this.title,
    this.description,
    this.priority,
    this.isCompleted = false,
    this.dueDate,
  });

  factory HomeTaskModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeTaskModel(
      id: _toNullableInt(
        json['id'] ??
            json['taskId'] ??
            json['TaskID'],
      ),
      title: _toString(
            json['title'] ??
                json['taskTitle'] ??
                json['TaskTitle'] ??
                json['name'] ??
                json['Name'],
          ) ??
          'مهمة بدون عنوان',
      description: _toString(
        json['description'] ??
            json['Description'],
      ),
      priority: _toString(
        json['priority'] ??
            json['Priority'],
      ),
      isCompleted:
          _toBool(
        json['isCompleted'] ??
            json['completed'] ??
            json['IsCompleted'],
      ),
      dueDate: _parseDate(
        json['dueDate'] ??
            json['DueDate'],
      ),
    );
  }
}


// ============================================================
// الأنشطة الأخيرة
// ============================================================

class HomeActivityModel {
  final int? id;
  final String title;
  final String? description;
  final dynamic amount;
  final DateTime? date;

  const HomeActivityModel({
    this.id,
    required this.title,
    this.description,
    this.amount,
    this.date,
  });

  factory HomeActivityModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return HomeActivityModel(
      id: _toNullableInt(
        json['id'] ??
            json['activityId'] ??
            json['ActivityID'],
      ),
      title: _toString(
            json['title'] ??
                json['activityTitle'] ??
                json['ActivityTitle'] ??
                json['name'] ??
                json['Name'],
          ) ??
          'عملية',
      description: _toString(
        json['description'] ??
            json['Description'],
      ),
      amount:
          json['amount'] ??
          json['Amount'] ??
          json['value'] ??
          json['Value'],
      date: _parseDate(
        json['date'] ??
            json['createdAt'] ??
            json['CreatedAt'],
      ),
    );
  }
}


// ============================================================
// Helpers
// ============================================================

int? _toNullableInt(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString(),
  );
}

String? _toString(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  return text.isEmpty ? null : text;
}

bool _toBool(
  dynamic value,
) {
  if (value == true) {
    return true;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final text =
        value.toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  return false;
}

DateTime? _parseDate(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}