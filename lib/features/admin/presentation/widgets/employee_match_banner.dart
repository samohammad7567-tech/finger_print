import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_note_banner.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

/// Says why somebody enrolled on the terminal is missing from the list below.
///
/// The sync deliberately did not add them: they share a name with an employee
/// already here, and only an admin can say whether that is the same person.
/// Without this the absence looks like the sync failing, and the answer lives
/// on a screen there is otherwise no reason to open.
/// The way in, said as a label rather than a button: the whole banner is the
/// tap target, so a second one would be a lie about where to press.
Widget _action(BuildContext context, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      label,
      style: AppTextStyles.captionMedium.copyWith(
        fontWeight: FontWeight.w600,
        color: context.color.warningSoft,
      ),
    ),
    Icon(
      Icons.chevron_right,
      size: AppDimens.iconLg,
      color: context.color.warningSoft,
    ),
  ],
);

class EmployeeMatchBanner extends StatelessWidget {
  const EmployeeMatchBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          // A drill-down, not a branch: the terminal screen is pushed over this
          // one, so returning lands back here with the list still built and the
          // count still the one the admin set out to clear. Re-reading it is
          // what makes the banner disappear once they have answered.
          onTap: () async {
            await context.push('/admin/device');
            if (!context.mounted) return;
            await context.read<EmployeeManagementCubit>().load();
          },
          child: AppNoteBanner(
            icon: Icons.help_outline,
            iconSize: 20,
            title: LangKeys.employeeMatchBannerTitle.tr(args: ['$count']),
            text: LangKeys.employeeMatchBannerHint.tr(),
            color: context.color.warningSoft,
            tintAlpha: 0.12,
            borderAlpha: 0.35,
            radius: 14,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: 10,
            ),
            crossAxisAlignment: CrossAxisAlignment.center,
            trailing: _action(context, LangKeys.employeeMatchBannerAction.tr()),
          ),
        ),
      ),
    );
  }
}
