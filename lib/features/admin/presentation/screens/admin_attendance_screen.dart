import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../permissions/data/repos/permissions_repo.dart';
import '../../../holidays/data/repos/holidays_repo.dart';
import '../../../shifts/data/repos/shifts_repo.dart';
import '../../data/repos/monthly_report_pdf_repo.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../refactor/admin_attendance_body.dart';

class AdminAttendanceScreen extends StatelessWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminAttendanceCubit(
        getIt<AttendanceRepo>(),
        getIt<PermissionsRepo>(),
        getIt<ShiftsRepo>(),
        getIt<HolidaysRepo>(),
        getIt<MonthlyReportPdfRepo>(),
      )..loadDay(),
      child: const AdminAttendanceBody(),
    );
  }
}
