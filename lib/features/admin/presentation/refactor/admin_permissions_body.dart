import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_compact_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
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
      listenWhen: (prev, curr) => prev.error != curr.error,
      listener: (context, state) {
        // Every failure this cubit emits is a [LangKeys] constant, so it is
        // translated here. It used to be compared against a string the cubit
        // never emits and then shown raw — which is why a refused vacation
        // read "vacation_limit_error" on screen.
        if (state.error != null) AppToast.error(context, state.error!.tr());
      },
      builder: (context, state) {
        return Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        LangKeys.adminPermissionsMgmt.tr(),
                        style: AppTextStyles.heading.copyWith(
                          color: context.color.foreground,
                        ),
                      ),
                      AppCompactButton(
                        label: LangKeys.add.tr(),
                        icon: Icons.add,
                        onPressed: () => context
                            .read<AdminPermissionsCubit>()
                            .toggleForm(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  const PermissionFilterTabs(),
                  const SizedBox(height: AppDimens.spaceMd),
                  Expanded(child: _content(context, state)),
                ],
              ),
            ),
            if (state.showForm) _form(context, state),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, AdminPermissionsState state) {
    if (state.isLoading) {
      return ListView.separated(
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
        itemBuilder: (_, _) =>
            const AppCardSkeleton(lines: 2, height: 80, showHeader: false),
      );
    }

    final filtered = state.filtered;

    if (state.error != null && state.permissions.isEmpty) {
      return AppErrorState(
        messageKey: state.error,
        onRetry: () => context.read<AdminPermissionsCubit>().load(),
      );
    }

    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.description_outlined,
        title: LangKeys.noPermissions.tr(),
        subtitle: LangKeys.addNewPermission.tr(),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
      itemBuilder: (_, i) => PermissionListItem(permission: filtered[i]),
    );
  }

  Widget _form(BuildContext context, AdminPermissionsState state) {
    final cubit = context.read<AdminPermissionsCubit>();

    return AddPermissionSheet(
      employees: state.employees,
      isSaving: state.isSaving,
      onClose: () => cubit.toggleForm(false),
      onSave:
          ({
            required employeeId,
            required employeeName,
            required permissionType,
            required date,
            reason,
            approvedBy,
          }) => cubit.savePermission(
            employeeId: employeeId,
            employeeName: employeeName,
            permissionType: permissionType,
            date: date,
            reason: reason,
            approvedBy: approvedBy,
          ),
    );
  }
}
