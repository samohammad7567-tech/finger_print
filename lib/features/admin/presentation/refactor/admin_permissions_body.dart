import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../permissions/presentation/widgets/add_permission_sheet.dart';
import '../cubit/admin_permissions_cubit.dart';
import '../widgets/permission_filter_tabs.dart';
import '../widgets/permission_list_item.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminPermissionsBody extends StatelessWidget {
  const AdminPermissionsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminPermissionsCubit, AdminPermissionsState>(
      listener: (context, state) {
        if (state.error != null) {
          final message = state.error == 'vacation_limit_reached'
              ? LangKeys.vacationLimitError.tr()
              : state.error!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: state.error == 'vacation_limit_reached'
                  ? context.color.destructive
                  : null,
            ),
          );
          context.read<AdminPermissionsCubit>().clearError();
        }
      },
      builder: (context, state) {
        final filtered = state.filtered;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LangKeys.adminPermissionsMgmt.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _AddButton(
                        onTap: () => context
                            .read<AdminPermissionsCubit>()
                            .toggleForm(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const PermissionFilterTabs(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.isLoading
                        ? _buildShimmer(context)
                        : filtered.isEmpty
                        ? Center(
                            child: Text(
                              LangKeys.noPermissions.tr(),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                PermissionListItem(permission: filtered[i]),
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
                    context.read<AdminPermissionsCubit>().toggleForm(false),
                onSave:
                    ({
                      required employeeId,
                      required employeeName,
                      required permissionType,
                      required date,
                      reason,
                      approvedBy,
                    }) => context.read<AdminPermissionsCubit>().savePermission(
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
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.separated(
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 80,
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
}
