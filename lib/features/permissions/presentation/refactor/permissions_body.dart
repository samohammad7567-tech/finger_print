import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/permissions_cubit.dart';
import '../cubit/permissions_state.dart';
import '../widgets/permission_card.dart';
import '../widgets/add_permission_sheet.dart';
import '../../../../core/style/theme/context_extension.dart';

class PermissionsBody extends StatelessWidget {
  const PermissionsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionsCubit, PermissionsState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<PermissionsCubit>().clearError();
      },
      child: BlocBuilder<PermissionsCubit, PermissionsState>(
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LangKeys.permissionsAndRequests.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildAddButton(context),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      hint: LangKeys.search.tr(),
                      prefixIcon: Icons.search,
                      onChanged: (v) =>
                          context.read<PermissionsCubit>().setSearch(v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: state.isLoading
                          ? _buildShimmer(context)
                          : state.filtered.isEmpty
                          ? Center(
                              child: Text(
                                LangKeys.noPermissions.tr(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: state.filtered.length,
                              padding: const EdgeInsets.only(bottom: 16),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) =>
                                  PermissionCard(permission: state.filtered[i]),
                            ),
                    ),
                  ],
                ),
              ),
              if (state.showForm)
                AddPermissionSheet(
                  employees: state.employees,
                  isSaving: state.isSaving,
                  onClose: () =>
                      context.read<PermissionsCubit>().toggleForm(false),
                  onSave:
                      ({
                        required employeeId,
                        required employeeName,
                        required permissionType,
                        required date,
                        reason,
                        approvedBy,
                      }) => context.read<PermissionsCubit>().savePermission(
                        employeeId: employeeId,
                        employeeName: employeeName,
                        permissionType: permissionType,
                        date: date,
                        reason: reason,
                        approvedBy: approvedBy,
                      ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<PermissionsCubit>().toggleForm(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.color.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: context.color.primaryForeground),
            const SizedBox(width: 4),
            Text(
              LangKeys.add.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.color.primaryForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 96,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
