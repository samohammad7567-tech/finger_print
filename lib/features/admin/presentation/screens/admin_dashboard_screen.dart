import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../cubit/admin_dashboard_cubit.dart';
import '../refactor/admin_dashboard_body.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminDashboardCubit(getIt<AttendanceRepo>())..load(),
      child: const AdminDashboardBody(),
    );
  }
}
