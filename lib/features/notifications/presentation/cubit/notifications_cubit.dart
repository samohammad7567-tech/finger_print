import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../settings/data/repos/settings_repo.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final AttendanceRepo _repo;
  final SettingsRepo _settingsRepo;

  NotificationsCubit(this._repo, this._settingsRepo)
    : super(const NotificationsState());

  Future<void> load() async {
    try {
      final today = getTodayDate();
      final now = DateTime.now();
      final nowMins = now.hour * 60 + now.minute;

      final results = await Future.wait([
        _repo.getRecordsByDate(today),
        _repo.getEmployees(),
      ]);
      final records = results[0] as List<AttendanceRecordModel>;
      final employees = results[1] as List<EmployeeModel>;
      final notifs = <NotificationItem>[];
      final checkedIds = records.map((r) => r.employeeId).toSet();
      final showLateAlerts = _settingsRepo.getLateAlerts();
      final showMissingCheckout = _settingsRepo.getMissingCheckoutAlerts();

      if (showLateAlerts)
        for (final r in records.where((r) => r.status == 'late')) {
          notifs.add(
            NotificationItem(
              id: 'late-${r.id}',
              type: 'warning',
              icon: Icons.access_time,
              title: 'late_employee',
              body: '${r.employeeName} — ${r.checkInTime}',
              time: r.checkInTime,
            ),
          );
        }

      if (showMissingCheckout && nowMins >= 17 * 60) {
        for (final r in records.where(
          (r) =>
              r.checkInTime != null &&
              r.checkOutTime == null &&
              r.status != 'absent',
        )) {
          notifs.add(
            NotificationItem(
              id: 'missing-co-${r.id}',
              type: 'danger',
              icon: Icons.warning_amber_rounded,
              title: 'missing_checkout',
              body: r.employeeName ?? '',
              time: r.checkInTime,
            ),
          );
        }
      }

      if (nowMins >= 9 * 60 + 30) {
        for (final e in employees.where((e) => !checkedIds.contains(e.id))) {
          notifs.add(
            NotificationItem(
              id: 'not-in-${e.id}',
              type: 'danger',
              icon: Icons.person_off,
              title: 'not_checked_in',
              body: '${e.fullName} — ${e.department}',
            ),
          );
        }
      }

      emit(state.copyWith(notifications: notifs, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
