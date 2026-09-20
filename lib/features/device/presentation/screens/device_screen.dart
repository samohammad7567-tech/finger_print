import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../cubit/device_cubit.dart';
import '../refactor/device_body.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A singleton, so the auto-sync timer it owns survives leaving this screen.
    return BlocProvider.value(
      value: getIt<DeviceCubit>()..load(),
      child: const DeviceBody(),
    );
  }
}
