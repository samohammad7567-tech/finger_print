import 'dart:convert';

/// One break: when the person left and when they came back.
///
/// [backIn] is null while they are still away — or when they never scanned on
/// their return, which happens and must not swallow the departure.
class AttendanceBreak {
  final String out;
  final String? backIn;

  const AttendanceBreak({required this.out, this.backIn});

  bool get isClosed => backIn != null && backIn!.isNotEmpty;

  /// How long it lasted, or null while it is still open.
  Duration? get length {
    final from = _minutes(out);
    final to = _minutes(backIn);
    if (from == null || to == null || to <= from) return null;
    return Duration(minutes: to - from);
  }

  factory AttendanceBreak.fromJson(Map<String, dynamic> json) =>
      AttendanceBreak(
        out: json['out'] as String? ?? '',
        backIn: json['in'] as String?,
      );

  Map<String, dynamic> toJson() => {'out': out, 'in': backIn};

  static int? _minutes(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }

  /// Reads the `breaks` column, which arrives as JSON text from SQLite and as a
  /// plain list when a record is round-tripped in memory.
  static List<AttendanceBreak> listFrom(Object? value) {
    final raw = switch (value) {
      String v when v.trim().isNotEmpty => jsonDecode(v),
      List v => v,
      _ => null,
    };
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AttendanceBreak.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => b.out.isNotEmpty)
        .toList();
  }

  /// The column value: JSON text, or null when the day had no break at all.
  static String? encode(List<AttendanceBreak> breaks) => breaks.isEmpty
      ? null
      : jsonEncode(breaks.map((b) => b.toJson()).toList());
}

class AttendanceRecordModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;

  /// The first departure and the last return of the day — a summary of
  /// [breaks], kept as columns of their own because that is how the day was
  /// stored before a day could hold more than one break.
  final String? breakOutTime;
  final String? breakInTime;

  /// Every break the person took, in order.
  final List<AttendanceBreak> breaks;

  final String? overtimeInTime;
  final String? overtimeOutTime;

  final String status;
  final String? notes;
  final bool isSynced;
  final String? guardName;
  final bool isEarlyLeave;

  /// When an admin corrected this day's punches, if they have.
  ///
  /// Its presence spends their one chance at the day and freezes the record
  /// against the device fold.
  final String? correctedAt;

  /// Who made that correction, for the trail it leaves behind.
  final String? correctedBy;

  const AttendanceRecordModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.breakOutTime,
    this.breakInTime,
    this.breaks = const [],
    this.overtimeInTime,
    this.overtimeOutTime,
    this.status = 'pending',
    this.notes,
    this.isSynced = true,
    this.guardName,
    this.isEarlyLeave = false,
    this.correctedAt,
    this.correctedBy,
  });

  bool get isCorrected => correctedAt != null && correctedAt!.trim().isNotEmpty;

  /// Whether an admin may still correct this day, judged against [today].
  ///
  /// One rule in one place: the data source enforces it on the way in and the
  /// report asks it whether to offer the button at all. Two copies of it would
  /// drift, and the one that drifted would be the one people trusted.
  ///
  /// A day can be corrected on the day it happened — not before it, not after
  /// it — and only once. Somebody who does not report the mistake while it is
  /// still today has missed the window, and the report stands.
  bool canCorrectOn(DateTime today) => !isCorrected && date == isoDate(today);

  /// A date as the `date` column stores it.
  static String isoDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) =>
      AttendanceRecordModel(
        id: json['id'] as String? ?? '',
        employeeId: json['employee_id'] as String? ?? '',
        employeeName: json['employee_name'] as String?,
        date: json['date'] as String? ?? '',
        checkInTime: json['check_in_time'] as String?,
        checkOutTime: json['check_out_time'] as String?,
        breakOutTime: json['break_out_time'] as String?,
        breakInTime: json['break_in_time'] as String?,
        breaks: AttendanceBreak.listFrom(json['breaks']),
        overtimeInTime: json['overtime_in_time'] as String?,
        overtimeOutTime: json['overtime_out_time'] as String?,
        status: json['status'] as String? ?? 'pending',
        notes: json['notes'] as String?,
        isSynced: _bool(json['is_synced'], fallback: true),
        guardName: json['guard_name'] as String?,
        isEarlyLeave: _bool(json['is_early_leave']),
        correctedAt: json['corrected_at'] as String?,
        correctedBy: json['corrected_by'] as String?,
      );

  /// SQLite stores booleans as 1/0, so a row read back needs widening that the
  /// old JSON payloads did not.
  static bool _bool(Object? value, {bool fallback = false}) => switch (value) {
    bool v => v,
    int v => v != 0,
    _ => fallback,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'date': date,
    'check_in_time': checkInTime,
    'check_out_time': checkOutTime,
    'break_out_time': breakOutTime,
    'break_in_time': breakInTime,
    'breaks': AttendanceBreak.encode(breaks),
    'overtime_in_time': overtimeInTime,
    'overtime_out_time': overtimeOutTime,
    'status': status,
    'notes': notes,
    'is_synced': isSynced,
    'guard_name': guardName,
    'is_early_leave': isEarlyLeave,
    'corrected_at': correctedAt,
    'corrected_by': correctedBy,
  };

  AttendanceRecordModel copyWith({
    String? checkInTime,
    String? checkOutTime,
    String? breakOutTime,
    String? breakInTime,
    List<AttendanceBreak>? breaks,
    String? overtimeInTime,
    String? overtimeOutTime,
    String? status,
    String? notes,
    bool? isEarlyLeave,
  }) => AttendanceRecordModel(
    id: id,
    employeeId: employeeId,
    employeeName: employeeName,
    date: date,
    checkInTime: checkInTime ?? this.checkInTime,
    checkOutTime: checkOutTime ?? this.checkOutTime,
    breakOutTime: breakOutTime ?? this.breakOutTime,
    breakInTime: breakInTime ?? this.breakInTime,
    breaks: breaks ?? this.breaks,
    overtimeInTime: overtimeInTime ?? this.overtimeInTime,
    overtimeOutTime: overtimeOutTime ?? this.overtimeOutTime,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    isSynced: isSynced,
    guardName: guardName,
    isEarlyLeave: isEarlyLeave ?? this.isEarlyLeave,
    correctedAt: correctedAt,
    correctedBy: correctedBy,
  );
}
