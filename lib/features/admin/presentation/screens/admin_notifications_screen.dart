import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../refactor/admin_notifications_body.dart';

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AdminNotificationsCubit>()..load(),
      child: const AdminNotificationsBody(),
    );
  }
}
