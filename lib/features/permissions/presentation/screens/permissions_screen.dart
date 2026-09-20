import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../cubit/permissions_cubit.dart';
import '../refactor/permissions_body.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key, this.openForm = false});

  final bool openForm;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PermissionsCubit>()..load(openForm: openForm),
      child: const PermissionsBody(),
    );
  }
}
