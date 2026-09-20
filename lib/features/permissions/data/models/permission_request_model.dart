class PermissionRequestModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? department;
  final String permissionType;
  final String date;
  final String? startTime;
  final String? endTime;
  final String? reason;
  final String status;
  final String? approvedBy;
  final String? notes;

  const PermissionRequestModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.department,
    required this.permissionType,
    required this.date,
    this.startTime,
    this.endTime,
    this.reason,
    this.status = 'approved',
    this.approvedBy,
    this.notes,
  });

  factory PermissionRequestModel.fromJson(Map<String, dynamic> json) =>
      PermissionRequestModel(
        id: json['id'] as String? ?? '',
        employeeId: json['employee_id'] as String? ?? '',
        employeeName: json['employee_name'] as String?,
        department: json['department'] as String?,
        permissionType: json['permission_type'] as String? ?? 'other',
        date: json['date'] as String? ?? '',
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        reason: json['reason'] as String?,
        status: json['status'] as String? ?? 'approved',
        approvedBy: json['approved_by'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'employee_name': employeeName,
    'department': department,
    'permission_type': permissionType,
    'date': date,
    'start_time': startTime,
    'end_time': endTime,
    'reason': reason,
    'status': status,
    'approved_by': approvedBy,
    'notes': notes,
  };
}
