import '../../../../core/utils/work_schedule.dart';
import '../../../attendance/data/models/employee_model.dart';

/// Every shift's hours, read once, so a screen can judge a whole month of
/// records without going back to the database for each employee.
///
/// Before shifts existed, each of these screens read one [WorkSchedule] and
/// measured everybody by it. They now read one of these instead and ask it per
/// employee — the shape of the call sites barely moved, but the answer is that
/// person's own working day.
///
/// [companyDefault] is the answer for anybody not on a shift, and for anybody
/// whose shift has since been deleted. It is the hours from the work-hours
/// settings screen, which is what the whole app used before this existed.
class ShiftSchedules {
  final WorkSchedule companyDefault;

  /// Every shift's hours, by shift id. Read-only in practice — nothing holding
  /// one of these has any reason to change what a shift means.
  final Map<String, WorkSchedule> byShiftId;

  const ShiftSchedules({
    this.companyDefault = const WorkSchedule(),
    this.byShiftId = const {},
  });

  /// The hours [shiftId] means. A shift nobody can find any more resolves to
  /// the company default rather than throwing: an employee left pointing at a
  /// deleted shift must still have a day that can be judged.
  WorkSchedule forShiftId(String? shiftId) {
    if (shiftId == null || shiftId.isEmpty) return companyDefault;
    return byShiftId[shiftId] ?? companyDefault;
  }

  /// The hours this employee's day is judged by.
  WorkSchedule of(EmployeeModel employee) => forShiftId(employee.shiftId);

  /// True when no shift has been set up, so everybody is on the company
  /// default. What the employee form reads to decide whether choosing a shift
  /// is something the admin has to do at all.
  bool get isEmpty => byShiftId.isEmpty;
}
