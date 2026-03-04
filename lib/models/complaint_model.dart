// ===================================
// نموذج الشكوى
// ===================================
class ComplaintModel {
  final int complaintId;
  final int partyId;
  final String? clientName;
  final String? phone;
  final String? phone2;
  final String? address;
  final int? opportunityId;
  final String? opportunityProduct;
  final int typeId;
  final String? complaintType;
  final String subject;
  final String details;
  final int priority;
  final int status;
  final int? assignedTo;
  final String? assignedToName;
  final String? assignedToPhone;
  final DateTime? complaintDate;
  final String? createdBy;
  final DateTime? createdAt;
  final bool escalated;
  final int? escalatedTo;
  final String? escalatedToName;
  final int? escalatedBy;
  final String? escalatedByName;
  final DateTime? escalatedAt;
  final String? escalationReason;
  final String? solution;
final DateTime? solvedDate;
final int? satisfactionLevel;

  ComplaintModel({
    required this.complaintId,
    required this.partyId,
    this.clientName,
    this.phone,
    this.phone2,
    this.address,
    this.opportunityId,
    this.opportunityProduct,
    required this.typeId,
    this.complaintType,
    required this.subject,
    required this.details,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.assignedToPhone,
    this.complaintDate,
    this.createdBy,
    this.createdAt,
    this.escalated = false,
    this.escalatedTo,
    this.escalatedToName,
    this.escalatedBy,
    this.escalatedByName,
    this.escalatedAt,
    this.escalationReason,
    this.solution,
this.solvedDate,
this.satisfactionLevel,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      complaintId: json['ComplaintID'] ?? 0,
      partyId: json['PartyID'] ?? 0,
      clientName: json['ClientName'],
      phone: json['Phone'],
      phone2: json['Phone2'],
      address: json['Address'],
      opportunityId: json['OpportunityID'],
      opportunityProduct: json['OpportunityProduct'],
      typeId: json['TypeID'] ?? 0,
      complaintType: json['ComplaintType'],
      subject: json['Subject'] ?? '',
      details: json['Details'] ?? '',
      priority: json['Priority'] ?? 3,
      status: json['Status'] ?? 1,
      assignedTo: json['AssignedTo'],
      assignedToName: json['AssignedToName'],
      assignedToPhone: json['AssignedToPhone'],
      complaintDate: json['ComplaintDate'] != null
          ? DateTime.tryParse(json['ComplaintDate'].toString())
          : null,
      createdBy: json['CreatedBy'],
      createdAt: json['CreatedAt'] != null
          ? DateTime.tryParse(json['CreatedAt'].toString())
          : null,
      escalated: json['Escalated'] == true || json['Escalated'] == 1,
      escalatedTo: json['EscalatedTo'],
      escalatedToName: json['EscalatedToName'],
      escalatedBy: json['EscalatedBy'],
      escalatedByName: json['EscalatedByName'],
      escalatedAt: json['EscalatedAt'] != null
          ? DateTime.tryParse(json['EscalatedAt'].toString())
          : null,
      escalationReason: json['EscalationReason'],
      solution: json['Solution'],
solvedDate: json['SolvedDate'] != null
    ? DateTime.tryParse(json['SolvedDate'].toString())
    : null,
satisfactionLevel: json['SatisfactionLevel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partyId': partyId,
      'opportunityId': opportunityId,
      'typeId': typeId,
      'subject': subject,
      'details': details,
      'priority': priority,
      'status': status,
      'assignedTo': assignedTo,
      'complaintDate': complaintDate?.toIso8601String(),
    };
  }

  // ===================================
  // Helpers للحالة
  // ===================================
  String get statusText {
    switch (status) {
      case 1: return 'جديدة';
      case 2: return 'قيد الحل';
      case 3: return 'انتظار';
      case 4: return 'محلولة';
      case 5: return 'مرفوضة';
      case 6: return 'مصعدة';
      default: return 'غير محدد';
    }
  }

  String get priorityText {
    switch (priority) {
      case 1: return 'عالية جداً';
      case 2: return 'عالية';
      case 3: return 'متوسطة';
      case 4: return 'منخفضة';
      default: return 'غير محدد';
    }
  }
}

// ===================================
// نموذج المتابعة
// ===================================
class FollowUpModel {
  final int followUpId;
  final int complaintId;
  final DateTime? followUpDate;
  final int? followUpBy;
  final String? followUpByName;
  final String notes;
  final String? actionTaken;
  final DateTime? nextFollowUpDate;

  FollowUpModel({
    required this.followUpId,
    required this.complaintId,
    this.followUpDate,
    this.followUpBy,
    this.followUpByName,
    required this.notes,
    this.actionTaken,
    this.nextFollowUpDate,
  });

  factory FollowUpModel.fromJson(Map<String, dynamic> json) {
    return FollowUpModel(
      followUpId: json['FollowUpID'] ?? 0,
      complaintId: json['ComplaintID'] ?? 0,
      followUpDate: json['FollowUpDate'] != null
          ? DateTime.tryParse(json['FollowUpDate'].toString())
          : null,
      followUpBy: json['FollowUpBy'],
      followUpByName: json['FollowUpByName'],
      notes: json['Notes'] ?? '',
      actionTaken: json['ActionTaken'],
      nextFollowUpDate: json['NextFollowUpDate'] != null
          ? DateTime.tryParse(json['NextFollowUpDate'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'complaintId': complaintId,
      'followUpBy': followUpBy,
      'notes': notes,
      'actionTaken': actionTaken,
      'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
    };
  }
}

// ===================================
// نموذج نوع الشكوى
// ===================================
class ComplaintTypeModel {
  final int typeId;
  final String? typeName;
  final String? typeNameAr;

  ComplaintTypeModel({
    required this.typeId,
    this.typeName,
    this.typeNameAr,
  });

  factory ComplaintTypeModel.fromJson(Map<String, dynamic> json) {
    return ComplaintTypeModel(
      typeId: json['TypeID'] ?? 0,
      typeName: json['TypeName'],
      typeNameAr: json['TypeNameAr'],
    );
  }
}