import '../../../../core/utils/work_schedule.dart';

/// One working day the company runs, as the admin defined it.
///
/// The four things an admin sets are the whole of it: when the day starts,
/// when it ends, how much lateness it forgives and how early a departure it
/// forgives. Everything else a judgement needs — the overtime window — is
/// derived from the company default by [scheduleFrom], so a site adding an
/// evening shift does not have to key the overtime hours in a second time.
///
/// [inUse] is the number of employees on it. Not stored: it is counted on each
/// read, because it is what the admin is warned with before deleting a shift
/// and a stale count there would be worse than none.
class ShiftModel {
  final String id;
  final String name;

  /// 'HH:mm'.
  final String startWork;
  final String endWork;

  /// Minutes past [startWork] that are still on time.
  final int lateGraceMinutes;

  /// Minutes before the end of the day that are still an acceptable departure.
  final int earlyOutGraceMinutes;

  /// The weekdays this shift does not work, as [DateTime.weekday] numbers.
  /// Empty means it works every day, which is what every shift created before
  /// the calendar existed does.
  final Set<int> restDays;

  final int inUse;

  const ShiftModel({
    required this.id,
    required this.name,
    required this.startWork,
    required this.endWork,
    this.lateGraceMinutes = 0,
    this.earlyOutGraceMinutes = 0,
    this.restDays = const {},
    this.inUse = 0,
  });

  /// The hours the whole app judges this shift's people by.
  ///
  /// [companyDefault] supplies the overtime window's distance from the end of
  /// the day; see [WorkSchedule.forShift].
  WorkSchedule scheduleFrom(WorkSchedule companyDefault) =>
      companyDefault.forShift(
        startWork: startWork,
        endWork: endWork,
        lateGraceMinutes: lateGraceMinutes,
        earlyOutGraceMinutes: earlyOutGraceMinutes,
        restDays: restDays,
      );

  /// The schedule for a row read straight from the database — an employee
  /// joined to their shift, where every shift column is null when they are on
  /// none. Falls back to [companyDefault], which is also what a `shift_id`
  /// left pointing at a deleted shift resolves to.
  ///
  /// Shared by the two data sources that resolve a schedule inside SQL rather
  /// than in a cubit, so a punch folded by the device and a punch corrected by
  /// hand are judged by exactly the same hours.
  static WorkSchedule scheduleFromRow(
    Map<String, Object?> row,
    WorkSchedule companyDefault, {
    String prefix = '',
  }) {
    final start = row['${prefix}start_work'] as String?;
    final end = row['${prefix}end_work'] as String?;
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return companyDefault;
    }
    return companyDefault.forShift(
      startWork: start,
      endWork: end,
      lateGraceMinutes: (row['${prefix}late_grace_minutes'] as int?) ?? 0,
      earlyOutGraceMinutes:
          (row['${prefix}early_out_grace_minutes'] as int?) ?? 0,
      restDays: WorkSchedule.parseRestDays(
        row['${prefix}rest_days'] as String?,
      ),
    );
  }

  factory ShiftModel.fromJson(Map<String, dynamic> json) => ShiftModel(
    id: json['id'] as String? ?? '',
    name: (json['name'] as String? ?? '').trim(),
    startWork: json['start_work'] as String? ?? '',
    endWork: json['end_work'] as String? ?? '',
    lateGraceMinutes: (json['late_grace_minutes'] as int?) ?? 0,
    earlyOutGraceMinutes: (json['early_out_grace_minutes'] as int?) ?? 0,
    restDays: WorkSchedule.parseRestDays(json['rest_days'] as String?),
    inUse: (json['in_use'] as int?) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start_work': startWork,
    'end_work': endWork,
    'late_grace_minutes': lateGraceMinutes,
    'early_out_grace_minutes': earlyOutGraceMinutes,
    'rest_days': WorkSchedule.encodeRestDays(restDays),
  };

  ShiftModel copyWith({
    String? name,
    String? startWork,
    String? endWork,
    int? lateGraceMinutes,
    int? earlyOutGraceMinutes,
    Set<int>? restDays,
  }) => ShiftModel(
    id: id,
    name: name ?? this.name,
    startWork: startWork ?? this.startWork,
    endWork: endWork ?? this.endWork,
    lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
    earlyOutGraceMinutes: earlyOutGraceMinutes ?? this.earlyOutGraceMinutes,
    restDays: restDays ?? this.restDays,
    inUse: inUse,
  );

  /// A summary for the picker and the list: '09:00 – 17:00'.
  String get hours => '$startWork – $endWork';
}
