import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';
import '../cubit/employee_management_cubit.dart';
import 'employee_form_sheet.dart';

/// The staff list with nobody on it yet.
///
/// Offers both ways in, in the order they are actually used: a first employee
/// is rarely the real job — the admin usually has the whole staff list in a
/// file already — so the import sits beside the add button rather than being
/// discovered later in a toolbar.
class EmployeeListEmpty extends StatelessWidget {
  const EmployeeListEmpty({super.key, required this.isImporting});

  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AppIconBadge.tinted(
            icon: Icons.people_outline,
            color: context.color.primary,
            size: 48,
            radius: AppDimens.radiusLg,
            tintAlpha: 0.14,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            LangKeys.noEmployees.tr(),
            style: AppTextStyles.cardTitle.copyWith(
              color: context.color.foreground,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: AppDimens.controlHeight,
                child: FilledButton.icon(
                  onPressed: () => showEmployeeFormSheet(context),
                  icon: const Icon(Icons.add, size: AppDimens.iconMd),
                  label: Text(
                    LangKeys.addFirstEmployee.tr(),
                    style: AppTextStyles.controlSemiBold,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.color.primary,
                    foregroundColor: context.color.primaryForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              SizedBox(
                height: AppDimens.controlHeight,
                child: TextButton.icon(
                  onPressed: isImporting
                      ? null
                      : () => context
                            .read<EmployeeManagementCubit>()
                            .importFromExcel(
                              typeLabel: LangKeys.importFileType.tr(),
                              confirmLabel: LangKeys.importEmployees.tr(),
                            ),
                  icon: const Icon(
                    Icons.upload_file_outlined,
                    size: AppDimens.iconMd,
                  ),
                  label: Text(
                    LangKeys.importEmployees.tr(),
                    style: AppTextStyles.controlSemiBold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
