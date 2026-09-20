import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../permissions/data/repos/permissions_repo.dart';
import '../cubit/admin_permissions_cubit.dart';
import '../refactor/admin_permissions_body.dart';

class AdminPermissionsScreen extends StatelessWidget {
  const AdminPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminPermissionsCubit(
        getIt<PermissionsRepo>(),
        getIt<AttendanceRepo>(),
      )..load(),
      child: const AdminPermissionsBody(),
    );
  }
}
