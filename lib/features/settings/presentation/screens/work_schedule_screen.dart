import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/repos/settings_repo.dart';
import '../cubit/work_schedule_cubit.dart';
import '../refactor/work_schedule_body.dart';

class WorkScheduleScreen extends StatelessWidget {
  const WorkScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WorkScheduleCubit(getIt<SettingsRepo>())..load(),
      child: const WorkScheduleBody(),
    );
  }
}
