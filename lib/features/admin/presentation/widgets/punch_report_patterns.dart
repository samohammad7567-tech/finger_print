import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/glass_card.dart';
import '../refactor/employee_pattern.dart';
import 'employee_pattern_row.dart';

/// One line per person over the range, worst first.
///
/// The table below answers "what happened on this day". This answers "how is
/// this person doing", which is the question an admin actually opens the
/// report with — and the one they were previously left to work out by counting
/// rows by eye.
///
/// Sorted by days with issues rather than by name, because the whole value of
/// the list is that the people who need attention are at the top of it.
class PunchReportPatterns extends StatelessWidget {
  const PunchReportPatterns({super.key, required this.patterns});

  final List<EmployeePattern> patterns;

  @override
  Widget build(BuildContext context) {
    if (patterns.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.cardPadding,
              AppDimens.cardHeaderPaddingV,
              AppDimens.cardPadding,
              AppDimens.spaceSm,
            ),
            child: Text(
              LangKeys.reportPatterns.tr(),
              style: AppTextStyles.cardTitle.copyWith(
                color: context.color.foreground,
              ),
            ),
          ),
          for (final (index, pattern) in patterns.indexed) ...[
            if (index > 0) Divider(height: 1, color: context.color.borderSoft),
            EmployeePatternRow(pattern: pattern),
          ],
        ],
      ),
    );
  }
}
