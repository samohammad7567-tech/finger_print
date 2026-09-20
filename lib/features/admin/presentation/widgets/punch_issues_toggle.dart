import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/punch_report_cubit.dart';

/// Collapses a month of ordinary days away, so a pattern is what is left.
///
/// Shows the count beside it, so an admin can see there is nothing to filter
/// down to without tapping it and finding an empty table. Greyed out when the
/// range is clean — with one exception: it stays live while it is *on*, or
/// filtering down to nothing would trap them with no way back.
class PunchIssuesToggle extends StatelessWidget {
  const PunchIssuesToggle({super.key, required this.state});

  final PunchReportState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = state.issueCount;
    final enabled = count > 0 || state.issuesOnly;

    final onTap = enabled
        ? () =>
              context.read<PunchReportCubit>().setIssuesOnly(!state.issuesOnly)
        : null;

    final label = Text(
      '${LangKeys.reportIssuesOnly.tr()} ($count)',
      style: const TextStyle(fontSize: 11),
    );

    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    return state.issuesOnly
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: padding,
              minimumSize: Size.zero,
            ),
            child: label,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: padding,
              minimumSize: Size.zero,
              foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
            ),
            child: label,
          );
  }
}
