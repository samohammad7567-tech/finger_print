class EmployeeModel {
  final String id;
  final String? employeeId;
  final String? surname;
  final String fullName;
  final String? personalId;
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

  /// Finger slots the terminal held when the app last looked, as indices in the
  /// firmware's fixed order (0..9). The templates themselves stay on the
  /// device; this only lets the list and the form show how many are enrolled.
  final Set<int> enrolledFingers;

  /// The working day this person is judged by, or null for the company
  /// default. Null is the answer for every employee at a site that runs one
  /// set of hours, and for everybody on an install that predates shifts.
  final String? shiftId;

  final bool isActive;

  const EmployeeModel({
    required this.id,
    this.employeeId,
    this.surname,
    required this.fullName,
    this.personalId,
    required this.department,
    this.photoUrl,
    this.hasHousing = false,
    this.hasTravelPermission = false,
    this.phone,
    this.position,
    this.qrCode,
    this.deviceUserId,
    this.enrolledFingers = const {},
    this.shiftId,
    this.isActive = true,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
    id: json['id'] as String? ?? '',
    // The API called this `employee_id`; the SQLite column is
    // `employee_number`. Accepting both keeps rows read straight from the
    // database working — without this the number never round-tripped.
    employeeId: (json['employee_id'] ?? json['employee_number']) as String?,
    surname: json['surname'] as String?,
    fullName: json['full_name'] as String? ?? '',
    personalId: json['personal_id'] as String?,
    department: json['department'] as String? ?? '',
    photoUrl: json['photo_url'] as String?,
    hasHousing: _bool(json['has_housing']),
    hasTravelPermission: _bool(json['has_travel_permission']),
    phone: json['phone'] as String?,
    position: json['position'] as String?,
    qrCode: json['qr_code'] as String?,
    deviceUserId: json['device_user_id'] as String?,
    enrolledFingers: _fingers(json['enrolled_fingers']),
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

  /// SQLite stores the slots as "0,2,5"; an API-shaped map may carry a list.
  /// Anything outside the terminal's ten slots is dropped rather than shown.
  static Set<int> _fingers(Object? value) {
    final Iterable<Object?> raw = switch (value) {
      String v => v.split(','),
      List v => v,
      _ => const [],
    };
    final fingers = <int>{};
    for (final item in raw) {
      final finger = int.tryParse(item.toString().trim());
      if (finger != null && finger >= 0 && finger < 10) fingers.add(finger);
    }
    return fingers;
  }

  static String? _serializeFingers(Set<int> fingers) {
    if (fingers.isEmpty) return null;
    final sorted = fingers.toList()..sort();
    return sorted.join(',');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'surname': surname,
    'full_name': fullName,
    'personal_id': personalId,
    'department': department,
    'photo_url': photoUrl,
    'has_housing': hasHousing,
    'has_travel_permission': hasTravelPermission,
    'phone': phone,
    'position': position,
    'qr_code': qrCode,
    'device_user_id': deviceUserId,
    'enrolled_fingers': _serializeFingers(enrolledFingers),
    'shift_id': shiftId,
    'is_active': isActive,
  };

  EmployeeModel copyWith({
    String? surname,
    String? fullName,
    String? personalId,
    String? department,
    String? deviceUserId,
    bool clearDeviceUserId = false,
    Set<int>? enrolledFingers,
    String? shiftId,
    bool clearShiftId = false,
    bool? isActive,
  }) => EmployeeModel(
    id: id,
    employeeId: employeeId,
    surname: surname ?? this.surname,
    fullName: fullName ?? this.fullName,
    personalId: personalId ?? this.personalId,
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
    enrolledFingers: enrolledFingers ?? this.enrolledFingers,
    shiftId: clearShiftId ? null : (shiftId ?? this.shiftId),
    isActive: isActive ?? this.isActive,
  );
}
