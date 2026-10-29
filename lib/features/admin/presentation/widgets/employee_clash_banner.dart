import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_note_banner.dart';
import 'employee_name_clash_dialog.dart';

/// Says that two people on the list answer to the same name.
///
/// Stays up until somebody renames one of them: a duplicated name is not
/// urgent, but it silently makes the list ambiguous — and every punch filed
/// under it — and there is otherwise nothing on screen to say so.
class EmployeeClashBanner extends StatelessWidget {
  const EmployeeClashBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: AppNoteBanner(
        icon: Icons.people_alt_outlined,
        text: LangKeys.clashBanner.tr(args: <String>['$count']),
        color: context.color.warning,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        tintAlpha: 0.12,
        borderAlpha: 0.35,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        crossAxisAlignment: CrossAxisAlignment.center,
        onTap: () => showEmployeeNameClashDialog(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              LangKeys.clashReview.tr(),
              style: AppTextStyles.captionMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: context.color.warning,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: AppDimens.iconMd,
              color: context.color.warning,
            ),
          ],
        ),
      ),
    );
  }
}
