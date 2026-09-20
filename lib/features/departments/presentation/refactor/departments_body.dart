import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/departments_cubit.dart';
import '../widgets/department_delete_dialog.dart';
import '../widgets/department_name_dialog.dart';
import '../widgets/department_tile.dart';

class DepartmentsBody extends StatelessWidget {
  const DepartmentsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DepartmentsCubit, DepartmentsState>(
      listenWhen: (p, c) =>
          p.errorKey != c.errorKey || p.successKey != c.successKey,
      listener: (context, state) {
        if (state.errorKey != null) {
          AppToast.error(context, state.errorKey!.tr());
        }
        if (state.successKey != null) {
          AppToast.success(context, state.successKey!.tr());
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.departmentsTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                LangKeys.departmentsHint.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.isEmpty)
                AppEmptyState(
                  icon: Icons.apartment,
                  title: LangKeys.departmentsEmpty.tr(),
                  subtitle: LangKeys.departmentsEmptyHint.tr(),
                )
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (index, department)
                          in state.departments.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        DepartmentTile(
                          department: department,
                          onRename: () => showDepartmentNameDialog(
                            context,
                            department: department,
                          ),
                          onDelete: () =>
                              showDepartmentDeleteDialog(context, department),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                onPressed: state.isSaving
                    ? null
                    : () => showDepartmentNameDialog(context),
                label: LangKeys.departmentAdd.tr(),
                icon: Icons.add,
              ),
            ],
          ),
        );
      },
    );
  }
}
