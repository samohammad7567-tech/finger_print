import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../cubit/admin_reports_cubit.dart';
import '../refactor/admin_reports_body.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminReportsCubit(getIt<AttendanceRepo>())..load(),
      child: const AdminReportsBody(),
    );
  }
}
