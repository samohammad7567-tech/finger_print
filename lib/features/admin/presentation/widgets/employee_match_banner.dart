import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Says why somebody enrolled on the terminal is missing from the list below.
///
/// The sync deliberately did not add them: they share a name with an employee
/// already here, and only an admin can say whether that is the same person.
/// Without this the absence looks like the sync failing, and the answer lives
/// on a screen there is otherwise no reason to open.
class EmployeeMatchBanner extends StatelessWidget {
  const EmployeeMatchBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // A drill-down, not a branch: the terminal screen is pushed over this
          // one, so returning lands back here with the list still built and the
          // count still the one the admin set out to clear. Re-reading it is
          // what makes the banner disappear once they have answered.
          onTap: () async {
            await context.push('/admin/device');
            if (!context.mounted) return;
            await context.read<EmployeeManagementCubit>().load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.color.warningSoft.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.color.warningSoft.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20,
                  color: context.color.warningSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LangKeys.employeeMatchBannerTitle.tr(args: ['$count']),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.color.warningSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LangKeys.employeeMatchBannerHint.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LangKeys.employeeMatchBannerAction.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.color.warningSoft,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.color.warningSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
