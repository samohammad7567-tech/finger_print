import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../device/data/repos/device_repo.dart';
import '../../data/repos/employee_import_repo.dart';
import '../cubit/employee_management_cubit.dart';
import '../refactor/employee_management_body.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeeManagementCubit(
        getIt<AttendanceRepo>(),
        getIt<DeviceRepo>(),
        getIt<EmployeeImportRepo>(),
      )..load(),
      child: const EmployeeManagementBody(),
    );
  }
}
