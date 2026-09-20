class EmployeeModel {
  final String id;
  final String? employeeId;
  final String fullName;
  final String department;
  final String? photoUrl;
  final bool hasHousing;
  final bool hasTravelPermission;
  final String? phone;
  final String? position;
  final String? qrCode;

  /// The user id this employee is enrolled under on the ZKTeco terminal.
  /// Null until an admin maps them, and punches for an unmapped id are parked
  /// rather than discarded.
  final String? deviceUserId;

  /// The working day this person is judged by, or null for the company
  /// default. Null is the answer for every employee at a site that runs one
  /// set of hours, and for everybody on an install that predates shifts.
  final String? shiftId;

  final bool isActive;

  const EmployeeModel({
    required this.id,
    this.employeeId,
    required this.fullName,
    required this.department,
    this.photoUrl,
    this.hasHousing = false,
    this.hasTravelPermission = false,
    this.phone,
    this.position,
    this.qrCode,
    this.deviceUserId,
    this.shiftId,
    this.isActive = true,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
    id: json['id'] as String? ?? '',
    // The API called this `employee_id`; the SQLite column is
    // `employee_number`. Accepting both keeps rows read straight from the
    // database working — without this the number never round-tripped.
    employeeId: (json['employee_id'] ?? json['employee_number']) as String?,
    fullName: json['full_name'] as String? ?? '',
    department: json['department'] as String? ?? '',
    photoUrl: json['photo_url'] as String?,
    hasHousing: _bool(json['has_housing']),
    hasTravelPermission: _bool(json['has_travel_permission']),
    phone: json['phone'] as String?,
    position: json['position'] as String?,
    qrCode: json['qr_code'] as String?,
    deviceUserId: json['device_user_id'] as String?,
    shiftId: json['shift_id'] as String?,
    // SQLite has no boolean type, so a row read back carries 1/0 where the
    // old API sent true/false.
    isActive: _bool(json['is_active'], fallback: true),
  );

  static bool _bool(Object? value, {bool fallback = false}) => switch (value) {
    bool v => v,
    int v => v != 0,
    _ => fallback,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'full_name': fullName,
    'department': department,
    'photo_url': photoUrl,
    'has_housing': hasHousing,
    'has_travel_permission': hasTravelPermission,
    'phone': phone,
    'position': position,
    'qr_code': qrCode,
    'device_user_id': deviceUserId,
    'shift_id': shiftId,
    'is_active': isActive,
  };

  EmployeeModel copyWith({
    String? fullName,
    String? department,
    String? deviceUserId,
    bool clearDeviceUserId = false,
    String? shiftId,
    bool clearShiftId = false,
    bool? isActive,
  }) => EmployeeModel(
    id: id,
    employeeId: employeeId,
    fullName: fullName ?? this.fullName,
    department: department ?? this.department,
    photoUrl: photoUrl,
    hasHousing: hasHousing,
    hasTravelPermission: hasTravelPermission,
    phone: phone,
    position: position,
    qrCode: qrCode,
    deviceUserId: clearDeviceUserId
        ? null
        : (deviceUserId ?? this.deviceUserId),
    shiftId: clearShiftId ? null : (shiftId ?? this.shiftId),
    isActive: isActive ?? this.isActive,
  );
}
