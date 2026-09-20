import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../cubit/punch_report_cubit.dart';
import '../refactor/punch_report_body.dart';

class PunchReportScreen extends StatelessWidget {
  const PunchReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PunchReportCubit>()..load(),
      child: const PunchReportBody(),
    );
  }
}
