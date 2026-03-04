class EmployeeModel {
  final int employeeId;
  final String fullName;
  final String? jobTitle;
  final String? department;
  final String? mobilePhone;
  final int? bioEmployeeId;

  EmployeeModel({
    required this.employeeId,
    required this.fullName,
    this.jobTitle,
    this.department,
    this.mobilePhone,
    this.bioEmployeeId,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      employeeId: json['EmployeeID'] ?? 0,
      fullName: json['FullName'] ?? '',
      jobTitle: json['JobTitle'],
      department: json['Department'],
      mobilePhone: json['MobilePhone'],
      bioEmployeeId: json['BioEmployeeID'],
    );
  }
}