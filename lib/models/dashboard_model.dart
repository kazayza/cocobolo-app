// models/dashboard_model.dart

// ===================================================
// 📦 النموذج الرئيسي
// ===================================================
class DashboardData {
  final DashboardPeriod period;
  final KPIData kpi;
  final List<FunnelItem> funnel;
  final List<SourceItem> sources;
  final List<AdTypeItem> adTypes;
  final List<CategoryItem> categories;
  final List<LeaderboardItem> leaderboard;
  final List<LostReasonItem> lostReasons;
  final TrendData trend;
  final InteractionsData interactions;
  final TasksData tasks;
  final List<FollowUpItem> followUps;
  final List<StagnantItem> stagnant;
  final FilterLists filterLists;

  DashboardData({
    required this.period,
    required this.kpi,
    required this.funnel,
    required this.sources,
    required this.adTypes,
    required this.categories,
    required this.leaderboard,
    required this.lostReasons,
    required this.trend,
    required this.interactions,
    required this.tasks,
    required this.followUps,
    required this.stagnant,
    required this.filterLists,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      period: DashboardPeriod.fromJson(json['period'] ?? {}),
      kpi: KPIData.fromJson(json['kpi'] ?? {}),
      funnel: _parseList(json['funnel'], FunnelItem.fromJson),
      sources: _parseList(json['sources'], SourceItem.fromJson),
      adTypes: _parseList(json['adTypes'], AdTypeItem.fromJson),
      categories: _parseList(json['categories'], CategoryItem.fromJson),
      leaderboard: _parseList(json['leaderboard'], LeaderboardItem.fromJson),
      lostReasons: _parseList(json['lostReasons'], LostReasonItem.fromJson),
      trend: TrendData.fromJson(json['trend'] ?? {}),
      interactions: InteractionsData.fromJson(json['interactions'] ?? {}),
      tasks: TasksData.fromJson(json['tasks'] ?? {}),
      followUps: _parseList(json['followUps'], FollowUpItem.fromJson),
      stagnant: _parseList(json['stagnant'], StagnantItem.fromJson),
      filterLists: FilterLists.fromJson(json['filterLists'] ?? {}),
    );
  }

  static List<T> _parseList<T>(dynamic list, T Function(Map<String, dynamic>) fromJson) {
    if (list == null) return [];
    return (list as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
}

// ===================================================
// 📅 الفترة
// ===================================================
class DashboardPeriod {
  final String from;
  final String to;
  final String prevFrom;
  final String prevTo;
  final int diffDays;

  DashboardPeriod({
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
    required this.diffDays,
  });

  factory DashboardPeriod.fromJson(Map<String, dynamic> json) {
    return DashboardPeriod(
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      prevFrom: json['prevFrom'] ?? '',
      prevTo: json['prevTo'] ?? '',
      diffDays: json['diffDays'] ?? 30,
    );
  }
}

// ===================================================
// 📊 KPI
// ===================================================
class KPIData {
  final int currentOpportunities;
  final int currentWon;
  final int currentLost;
  final double currentExpectedRevenue;
  final double currentActualRevenue;
  final double currentCollected;
  final double currentConversion;
  final int currentAvgCloseTime;
  final double currentMarketingCost;

  final int prevOpportunities;
  final int prevWon;
  final int prevLost;
  final double prevExpectedRevenue;
  final double prevActualRevenue;
  final double prevConversion;
  final int prevAvgCloseTime;
  final double prevMarketingCost;

  final int todayTasks;
  final int overdueTasks;
  final int openComplaints;
  final int stagnantOpportunities;
  final int overdueFollowUps;

  KPIData({
    required this.currentOpportunities,
    required this.currentWon,
    required this.currentLost,
    required this.currentExpectedRevenue,
    required this.currentActualRevenue,
    required this.currentCollected,
    required this.currentConversion,
    required this.currentAvgCloseTime,
    required this.currentMarketingCost,
    required this.prevOpportunities,
    required this.prevWon,
    required this.prevLost,
    required this.prevExpectedRevenue,
    required this.prevActualRevenue,
    required this.prevConversion,
    required this.prevAvgCloseTime,
    required this.prevMarketingCost,
    required this.todayTasks,
    required this.overdueTasks,
    required this.openComplaints,
    required this.stagnantOpportunities,
    required this.overdueFollowUps,
  });

  factory KPIData.fromJson(Map<String, dynamic> json) {
    return KPIData(
      currentOpportunities: _toInt(json['currentOpportunities']),
      currentWon: _toInt(json['currentWon']),
      currentLost: _toInt(json['currentLost']),
      currentExpectedRevenue: _toDouble(json['currentExpectedRevenue']),
      currentActualRevenue: _toDouble(json['currentActualRevenue']),
      currentCollected: _toDouble(json['currentCollected']),
      currentConversion: _toDouble(json['currentConversion']),
      currentAvgCloseTime: _toInt(json['currentAvgCloseTime']),
      currentMarketingCost: _toDouble(json['currentMarketingCost']),
      prevOpportunities: _toInt(json['prevOpportunities']),
      prevWon: _toInt(json['prevWon']),
      prevLost: _toInt(json['prevLost']),
      prevExpectedRevenue: _toDouble(json['prevExpectedRevenue']),
      prevActualRevenue: _toDouble(json['prevActualRevenue']),
      prevConversion: _toDouble(json['prevConversion']),
      prevAvgCloseTime: _toInt(json['prevAvgCloseTime']),
      prevMarketingCost: _toDouble(json['prevMarketingCost']),
      todayTasks: _toInt(json['todayTasks']),
      overdueTasks: _toInt(json['overdueTasks']),
      openComplaints: _toInt(json['openComplaints']),
      stagnantOpportunities: _toInt(json['stagnantOpportunities']),
      overdueFollowUps: _toInt(json['overdueFollowUps']),
    );
  }

  // ===== حسابات النمو =====
  double _growth(double current, double prev) {
    if (prev == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - prev) / prev) * 100;
  }

  double get opportunitiesGrowth =>
      _growth(currentOpportunities.toDouble(), prevOpportunities.toDouble());
  double get wonGrowth =>
      _growth(currentWon.toDouble(), prevWon.toDouble());
  double get expectedRevenueGrowth =>
      _growth(currentExpectedRevenue, prevExpectedRevenue);
  double get actualRevenueGrowth =>
      _growth(currentActualRevenue, prevActualRevenue);
  double get conversionGrowth =>
      _growth(currentConversion, prevConversion);
  double get avgCloseTimeGrowth =>
      _growth(currentAvgCloseTime.toDouble(), prevAvgCloseTime.toDouble());
  double get marketingCostGrowth =>
      _growth(currentMarketingCost, prevMarketingCost);

  // ===== حسابات مالية =====
  // تكلفة اكتساب العميل
  double get cac =>
      currentWon > 0 ? currentMarketingCost / currentWon : 0;
  double get prevCac =>
      prevWon > 0 ? prevMarketingCost / prevWon : 0;
  double get cacGrowth => _growth(cac, prevCac);

  // العائد على الاستثمار
  double get roi => currentMarketingCost > 0
      ? ((currentActualRevenue - currentMarketingCost) / currentMarketingCost) * 100
      : 0;
  double get prevRoi => prevMarketingCost > 0
      ? ((prevActualRevenue - prevMarketingCost) / prevMarketingCost) * 100
      : 0;
  double get roiGrowth => _growth(roi, prevRoi);

  // نسبة التحصيل
  double get collectionRate =>
      currentActualRevenue > 0 ? (currentCollected / currentActualRevenue) * 100 : 0;

  // الفجوة بين المتوقع والفعلي
  double get revenueGap => currentExpectedRevenue - currentActualRevenue;

  // التنبيهات الكلية
  int get totalAlerts =>
      overdueTasks + overdueFollowUps + openComplaints + stagnantOpportunities;

  // ===== Helpers =====
  static int _toInt(dynamic v) => (v ?? 0) is int ? v ?? 0 : (v ?? 0).toInt();
  static double _toDouble(dynamic v) => (v ?? 0).toDouble();
}

// ===================================================
// 🔻 Funnel
// ===================================================
class FunnelItem {
  final int stageId;
  final String stageName;
  final String stageNameAr;
  final String? stageColor;
  final int stageOrder;
  final int count;
  final double totalValue;
  final double actualValue;

  FunnelItem({
    required this.stageId,
    required this.stageName,
    required this.stageNameAr,
    this.stageColor,
    required this.stageOrder,
    required this.count,
    required this.totalValue,
    required this.actualValue,
  });

  factory FunnelItem.fromJson(Map<String, dynamic> json) {
    return FunnelItem(
      stageId: json['StageID'] ?? 0,
      stageName: json['StageName'] ?? '',
      stageNameAr: json['StageNameAr'] ?? '',
      stageColor: json['StageColor'],
      stageOrder: json['StageOrder'] ?? 0,
      count: json['count'] ?? 0,
      totalValue: (json['totalValue'] ?? 0).toDouble(),
      actualValue: (json['actualValue'] ?? 0).toDouble(),
    );
  }
}

// ===================================================
// 🥧 Source
// ===================================================
class SourceItem {
  final int sourceId;
  final String name;
  final String? icon;
  final int total;
  final int won;
  final int lost;
  final double expectedRevenue;
  final double actualRevenue;
  final double conversionRate;
  final int avgCloseTime;

  SourceItem({
    required this.sourceId,
    required this.name,
    this.icon,
    required this.total,
    required this.won,
    required this.lost,
    required this.expectedRevenue,
    required this.actualRevenue,
    required this.conversionRate,
    required this.avgCloseTime,
  });

  factory SourceItem.fromJson(Map<String, dynamic> json) {
    return SourceItem(
      sourceId: json['SourceID'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
      total: json['total'] ?? 0,
      won: json['won'] ?? 0,
      lost: json['lost'] ?? 0,
      expectedRevenue: (json['expectedRevenue'] ?? 0).toDouble(),
      actualRevenue: (json['actualRevenue'] ?? 0).toDouble(),
      conversionRate: (json['conversionRate'] ?? 0).toDouble(),
      avgCloseTime: json['avgCloseTime'] ?? 0,
    );
  }
}

// ===================================================
// 📢 AdType
// ===================================================
class AdTypeItem {
  final int adTypeId;
  final String name;
  final int total;
  final int won;
  final int lost;
  final double actualRevenue;
  final double conversionRate;

  AdTypeItem({
    required this.adTypeId,
    required this.name,
    required this.total,
    required this.won,
    required this.lost,
    required this.actualRevenue,
    required this.conversionRate,
  });

  factory AdTypeItem.fromJson(Map<String, dynamic> json) {
    return AdTypeItem(
      adTypeId: json['AdTypeID'] ?? 0,
      name: json['name'] ?? '',
      total: json['total'] ?? 0,
      won: json['won'] ?? 0,
      lost: json['lost'] ?? 0,
      actualRevenue: (json['actualRevenue'] ?? 0).toDouble(),
      conversionRate: (json['conversionRate'] ?? 0).toDouble(),
    );
  }
}

// ===================================================
// 🏷️ Category
// ===================================================
class CategoryItem {
  final int categoryId;
  final String name;
  final int total;
  final int won;
  final int lost;
  final double actualRevenue;
  final double conversionRate;

  CategoryItem({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.won,
    required this.lost,
    required this.actualRevenue,
    required this.conversionRate,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      categoryId: json['CategoryID'] ?? 0,
      name: json['name'] ?? '',
      total: json['total'] ?? 0,
      won: json['won'] ?? 0,
      lost: json['lost'] ?? 0,
      actualRevenue: (json['actualRevenue'] ?? 0).toDouble(),
      conversionRate: (json['conversionRate'] ?? 0).toDouble(),
    );
  }
}

// ===================================================
// 🏆 Leaderboard
// ===================================================
class LeaderboardItem {
  final int employeeId;
  final String fullName;
  final int totalOpportunities;
  final int wonDeals;
  final int lostDeals;
  final double expectedRevenue;
  final double actualRevenue;
  final double conversionRate;
  final int avgCloseTime;
  final int totalInteractions;
  final double dailyActivityRate;
  final int completedTasks;
  final int overdueTasks;

  LeaderboardItem({
    required this.employeeId,
    required this.fullName,
    required this.totalOpportunities,
    required this.wonDeals,
    required this.lostDeals,
    required this.expectedRevenue,
    required this.actualRevenue,
    required this.conversionRate,
    required this.avgCloseTime,
    required this.totalInteractions,
    required this.dailyActivityRate,
    required this.completedTasks,
    required this.overdueTasks,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      employeeId: json['EmployeeID'] ?? 0,
      fullName: json['FullName'] ?? '',
      totalOpportunities: json['totalOpportunities'] ?? 0,
      wonDeals: json['wonDeals'] ?? 0,
      lostDeals: json['lostDeals'] ?? 0,
      expectedRevenue: (json['expectedRevenue'] ?? 0).toDouble(),
      actualRevenue: (json['actualRevenue'] ?? 0).toDouble(),
      conversionRate: (json['conversionRate'] ?? 0).toDouble(),
      avgCloseTime: json['avgCloseTime'] ?? 0,
      totalInteractions: json['totalInteractions'] ?? 0,
      dailyActivityRate: (json['dailyActivityRate'] ?? 0).toDouble(),
      completedTasks: json['completedTasks'] ?? 0,
      overdueTasks: json['overdueTasks'] ?? 0,
    );
  }
}

// ===================================================
// ❌ Lost Reason
// ===================================================
class LostReasonItem {
  final int lostReasonId;
  final String name;
  final int count;
  final double lostValue;
  final double? percentage;

  LostReasonItem({
    required this.lostReasonId,
    required this.name,
    required this.count,
    required this.lostValue,
    this.percentage,
  });

  factory LostReasonItem.fromJson(Map<String, dynamic> json) {
    return LostReasonItem(
      lostReasonId: json['LostReasonID'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      lostValue: (json['lostValue'] ?? 0).toDouble(),
      percentage: json['percentage']?.toDouble(),
    );
  }
}

// ===================================================
// 📈 Trend
// ===================================================
class TrendData {
  final String type;
  final List<TrendItem> data;

  TrendData({required this.type, required this.data});

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      type: json['type'] ?? 'daily',
      data: (json['data'] as List? ?? [])
          .map((e) => TrendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TrendItem {
  final String label;
  final int totalOpportunities;
  final int wonDeals;
  final int lostDeals;
  final double revenue;

  TrendItem({
    required this.label,
    required this.totalOpportunities,
    required this.wonDeals,
    required this.lostDeals,
    required this.revenue,
  });

  factory TrendItem.fromJson(Map<String, dynamic> json) {
    return TrendItem(
      label: json['label'] ?? '',
      totalOpportunities: json['totalOpportunities'] ?? 0,
      wonDeals: json['wonDeals'] ?? 0,
      lostDeals: json['lostDeals'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }
}

// ===================================================
// 💬 Interactions
// ===================================================
class InteractionsData {
  final InteractionsSummary summary;
  final List<NameCountItem> byStatus;
  final List<NameCountItem> bySource;

  InteractionsData({
    required this.summary,
    required this.byStatus,
    required this.bySource,
  });

  factory InteractionsData.fromJson(Map<String, dynamic> json) {
    return InteractionsData(
      summary: InteractionsSummary.fromJson(json['summary'] ?? {}),
      byStatus: _parseNameCount(json['byStatus']),
      bySource: _parseNameCount(json['bySource']),
    );
  }

  static List<NameCountItem> _parseNameCount(dynamic list) {
    if (list == null) return [];
    return (list as List)
        .map((e) => NameCountItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class InteractionsSummary {
  final int totalInteractions;
  final int uniqueOpportunities;
  final double avgPerOpportunity;
  final int stageChanges;

  InteractionsSummary({
    required this.totalInteractions,
    required this.uniqueOpportunities,
    required this.avgPerOpportunity,
    required this.stageChanges,
  });

  factory InteractionsSummary.fromJson(Map<String, dynamic> json) {
    return InteractionsSummary(
      totalInteractions: json['totalInteractions'] ?? 0,
      uniqueOpportunities: json['uniqueOpportunities'] ?? 0,
      avgPerOpportunity: (json['avgPerOpportunity'] ?? 0).toDouble(),
      stageChanges: json['stageChanges'] ?? 0,
    );
  }
}

// ===================================================
// ✅ Tasks
// ===================================================
class TasksData {
  final TasksSummary summary;
  final List<TaskTypeItem> byType;

  TasksData({required this.summary, required this.byType});

  factory TasksData.fromJson(Map<String, dynamic> json) {
    return TasksData(
      summary: TasksSummary.fromJson(json['summary'] ?? {}),
      byType: (json['byType'] as List? ?? [])
          .map((e) => TaskTypeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TasksSummary {
  final int totalTasks;
  final int completed;
  final int pending;
  final int inProgress;
  final int cancelled;
  final int overdue;
  final double completionRate;
  final int highPriority;
  final int normalPriority;
  final int lowPriority;

  TasksSummary({
    required this.totalTasks,
    required this.completed,
    required this.pending,
    required this.inProgress,
    required this.cancelled,
    required this.overdue,
    required this.completionRate,
    required this.highPriority,
    required this.normalPriority,
    required this.lowPriority,
  });

  factory TasksSummary.fromJson(Map<String, dynamic> json) {
    return TasksSummary(
      totalTasks: json['totalTasks'] ?? 0,
      completed: json['completed'] ?? 0,
      pending: json['pending'] ?? 0,
      inProgress: json['inProgress'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      overdue: json['overdue'] ?? 0,
      completionRate: (json['completionRate'] ?? 0).toDouble(),
      highPriority: json['highPriority'] ?? 0,
      normalPriority: json['normalPriority'] ?? 0,
      lowPriority: json['lowPriority'] ?? 0,
    );
  }
}

class TaskTypeItem {
  final String name;
  final int total;
  final int completed;

  TaskTypeItem({required this.name, required this.total, required this.completed});

  factory TaskTypeItem.fromJson(Map<String, dynamic> json) {
    return TaskTypeItem(
      name: json['name'] ?? '',
      total: json['total'] ?? 0,
      completed: json['completed'] ?? 0,
    );
  }
}

// ===================================================
// 🔔 Follow-up
// ===================================================
class FollowUpItem {
  final int opportunityId;
  final String clientName;
  final String? phone;
  final String? employeeName;
  final String stageName;
  final String? stageColor;
  final String nextFollowUpDate;
  final String? notes;
  final String followUpStatus;
  final int daysUntil;

  FollowUpItem({
    required this.opportunityId,
    required this.clientName,
    this.phone,
    this.employeeName,
    required this.stageName,
    this.stageColor,
    required this.nextFollowUpDate,
    this.notes,
    required this.followUpStatus,
    required this.daysUntil,
  });

  factory FollowUpItem.fromJson(Map<String, dynamic> json) {
    return FollowUpItem(
      opportunityId: json['OpportunityID'] ?? 0,
      clientName: json['clientName'] ?? '',
      phone: json['Phone'],
      employeeName: json['employeeName'],
      stageName: json['stageName'] ?? '',
      stageColor: json['StageColor'],
      nextFollowUpDate: json['NextFollowUpDate'] ?? '',
      notes: json['Notes'],
      followUpStatus: json['followUpStatus'] ?? '',
      daysUntil: json['daysUntil'] ?? 0,
    );
  }
}

// ===================================================
// 💤 Stagnant
// ===================================================
class StagnantItem {
  final int opportunityId;
  final String clientName;
  final String? phone;
  final String? employeeName;
  final String stageName;
  final String? stageColor;
  final String? lastUpdatedAt;
  final String? lastContactDate;
  final int daysSinceContact;
  final double? expectedValue;
  final String? notes;
  final String? lastInteractionSummary;

  StagnantItem({
    required this.opportunityId,
    required this.clientName,
    this.phone,
    this.employeeName,
    required this.stageName,
    this.stageColor,
    this.lastUpdatedAt,
    this.lastContactDate,
    required this.daysSinceContact,
    this.expectedValue,
    this.notes,
    this.lastInteractionSummary,
  });

  factory StagnantItem.fromJson(Map<String, dynamic> json) {
    return StagnantItem(
      opportunityId: json['OpportunityID'] ?? 0,
      clientName: json['clientName'] ?? '',
      phone: json['Phone'],
      employeeName: json['employeeName'],
      stageName: json['stageName'] ?? '',
      stageColor: json['StageColor'],
      lastUpdatedAt: json['LastUpdatedAt'],
      lastContactDate: json['LastContactDate'],
      daysSinceContact: json['daysSinceContact'] ?? 0,
      expectedValue: json['ExpectedValue']?.toDouble(),
      notes: json['Notes'],
      lastInteractionSummary: json['lastInteractionSummary'],
    );
  }
}

// ===================================================
// 🔽 Filter Lists
// ===================================================
class FilterLists {
  final List<FilterEmployee> employees;
  final List<FilterSource> sources;
  final List<FilterStage> stages;
  final List<FilterAdType> adTypes;

  FilterLists({
    required this.employees,
    required this.sources,
    required this.stages,
    required this.adTypes,
  });

  factory FilterLists.fromJson(Map<String, dynamic> json) {
    return FilterLists(
      employees: (json['employees'] as List? ?? [])
          .map((e) => FilterEmployee.fromJson(e as Map<String, dynamic>))
          .toList(),
      sources: (json['sources'] as List? ?? [])
          .map((e) => FilterSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      stages: (json['stages'] as List? ?? [])
          .map((e) => FilterStage.fromJson(e as Map<String, dynamic>))
          .toList(),
      adTypes: (json['adTypes'] as List? ?? [])
          .map((e) => FilterAdType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FilterEmployee {
  final int employeeId;
  final String fullName;

  FilterEmployee({required this.employeeId, required this.fullName});

  factory FilterEmployee.fromJson(Map<String, dynamic> json) {
    return FilterEmployee(
      employeeId: json['EmployeeID'] ?? 0,
      fullName: json['FullName'] ?? '',
    );
  }
}

class FilterSource {
  final int sourceId;
  final String name;
  final String? icon;

  FilterSource({required this.sourceId, required this.name, this.icon});

  factory FilterSource.fromJson(Map<String, dynamic> json) {
    return FilterSource(
      sourceId: json['SourceID'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
    );
  }
}

class FilterStage {
  final int stageId;
  final String name;
  final String? color;

  FilterStage({required this.stageId, required this.name, this.color});

  factory FilterStage.fromJson(Map<String, dynamic> json) {
    return FilterStage(
      stageId: json['StageID'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'],
    );
  }
}

class FilterAdType {
  final int adTypeId;
  final String name;

  FilterAdType({required this.adTypeId, required this.name});

  factory FilterAdType.fromJson(Map<String, dynamic> json) {
    return FilterAdType(
      adTypeId: json['AdTypeID'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

// ===================================================
// 🔧 Shared
// ===================================================
class NameCountItem {
  final String name;
  final String? icon;
  final int count;

  NameCountItem({required this.name, this.icon, required this.count});

  factory NameCountItem.fromJson(Map<String, dynamic> json) {
    return NameCountItem(
      name: json['name'] ?? '',
      icon: json['icon'],
      count: json['count'] ?? 0,
    );
  }
}