import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../cubit/check_in_cubit.dart';
import '../refactor/check_in_body.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key, this.initialMode = 'checkin'});

  final String initialMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CheckInCubit>()..init(initialMode),
      child: const CheckInBody(),
    );
  }
}
