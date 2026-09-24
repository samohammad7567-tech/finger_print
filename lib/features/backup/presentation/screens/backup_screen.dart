import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/repos/backup_repo.dart';
import '../cubit/backup_cubit.dart';
import '../refactor/backup_body.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupCubit(getIt<BackupRepo>())..load(),
      child: const BackupBody(),
    );
  }
}
