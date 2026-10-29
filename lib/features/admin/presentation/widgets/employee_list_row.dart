import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/employee_management_cubit.dart';
import 'delete_confirm_dialog.dart';
import 'employee_form_sheet.dart';

/// One person in the staff list: initial, name, the three badges that say what
/// they are entitled to, and the three actions.
///
/// A deactivated employee is drawn at half opacity rather than hidden — they
/// still own attendance history, and an admin looking for somebody who left
/// needs to find them.
class EmployeeListRow extends StatelessWidget {
  const EmployeeListRow({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: employee.isActive ? 1.0 : 0.5,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: <Widget>[
            _Initial(name: employee.fullName),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(child: _Identity(employee: employee)),
            _Actions(employee: employee),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.space2xl,
      height: AppDimens.space2xl,
      decoration: BoxDecoration(
        color: context.color.primary,
        borderRadius: BorderRadius.circular(AppDimens.radius),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.controlSemiBold.copyWith(
            color: context.color.primaryForeground,
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final enrolled = (employee.deviceUserId ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                employee.fullName,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySemiBold.copyWith(
                  color: context.color.foreground,
                ),
              ),
            ),
            if (employee.hasHousing)
              _Badge(
                icon: Icons.home,
                tone: context.color.success,
                tip: LangKeys.adminHasHousing.tr(),
              ),
            if (employee.hasTravelPermission)
              _Badge(
                icon: Icons.flight,
                tone: context.color.primary,
                tip: LangKeys.adminHasTravel.tr(),
              ),
            if (enrolled)
              _Badge(
                icon: Icons.fingerprint,
                tone: context.color.primary,
                tip: LangKeys.enrollEnrolled.tr(),
              ),
          ],
        ),
        Text(
          // "No department" is an ordinary choice, so the separator only
          // appears when there is something on both sides of it.
          <String>[
            if (employee.department.trim().isNotEmpty) employee.department,
            if ((employee.employeeId ?? '').isNotEmpty) employee.employeeId!,
          ].join(' · '),
          style: AppTextStyles.meta.copyWith(
            color: context.color.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// A badge was a bare icon with no name on it. The tooltip is what turns three
/// small glyphs into three facts an admin can read.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.tone, required this.tip});

  final IconData icon;
  final Color tone;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppDimens.spaceXs),
      child: Tooltip(
        message: tip,
        child: Icon(icon, size: AppDimens.iconXs, color: tone),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final active = employee.isActive;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: active
              ? LangKeys.employeeDeactivated.tr()
              : LangKeys.employeeActivated.tr(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            active ? Icons.person : Icons.person_off,
            size: AppDimens.iconMd,
            color: active
                ? context.color.success
                : context.color.subtleForeground,
          ),
          onPressed: () =>
              context.read<EmployeeManagementCubit>().toggleActive(employee),
        ),
        IconButton(
          tooltip: LangKeys.adminEditEmployee.tr(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.edit,
            size: AppDimens.iconMd,
            color: context.color.primary,
          ),
          onPressed: () => showEmployeeFormSheet(context, employee: employee),
        ),
        IconButton(
          tooltip: LangKeys.adminDelete.tr(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.delete,
            size: AppDimens.iconMd,
            color: context.color.destructive,
          ),
          onPressed: () => showDeleteConfirmDialog(context, employee),
        ),
      ],
    );
  }
}
