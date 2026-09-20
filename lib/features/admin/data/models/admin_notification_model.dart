class AdminNotificationModel {
  final String id;
  final String type;
  final String employeeId;
  final String employeeName;
  final String message;
  final String date;
  final int earlyLeaveCount;
  final bool isRead;

  const AdminNotificationModel({
    required this.id,
    required this.type,
    required this.employeeId,
    required this.employeeName,
    required this.message,
    required this.date,
    this.earlyLeaveCount = 0,
    this.isRead = false,
  });

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) =>
      AdminNotificationModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        employeeId: json['employee_id'] as String? ?? '',
        employeeName: json['employee_name'] as String? ?? '',
        message: json['message'] as String? ?? '',
        date: json['date'] as String? ?? '',
        earlyLeaveCount: json['early_leave_count'] as int? ?? 0,
        isRead: switch (json['is_read']) {
          // SQLite stores booleans as 1/0.
          bool v => v,
          int v => v != 0,
          _ => false,
        },
      );

  Map<String, dynamic> toJson() => {
    'type': type,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'message': message,
    'date': date,
    'early_leave_count': earlyLeaveCount,
    'is_read': isRead,
  };
}
