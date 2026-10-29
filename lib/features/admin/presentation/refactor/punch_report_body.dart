import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_table_skeleton.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/punch_report_cubit.dart';
import '../widgets/punch_report_filters.dart';
import '../widgets/punch_report_header.dart';
import '../widgets/punch_report_patterns.dart';
import '../widgets/punch_report_table.dart';
import '../widgets/punch_report_totals.dart';

/// The eleven columns of the report, in their relative widths, so the loading
/// skeleton stands in the same places the real cells will.
const _reportColumns = <int>[4, 2, 2, 2, 2, 3, 2, 2, 2, 2, 1];

class PunchReportBody extends StatelessWidget {
  const PunchReportBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PunchReportCubit, PunchReportState>(
      listenWhen: (p, c) => p.error != c.error || p.message != c.message,
      listener: (context, state) {
        if (state.error != null) AppToast.error(context, state.error!.tr());
        if (state.message != null) {
          AppToast.success(context, state.message!.tr(args: state.messageArgs));
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PunchReportHeader(state: state),
            const PunchReportFilters(),
            const SizedBox(height: AppDimens.spaceSm),
            Expanded(child: _content(context, state)),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, PunchReportState state) {
    if (state.isLoading) return const _ReportSkeleton();

    // An error with nothing on screen behind it is a load that failed, and the
    // toast that announced it is already gone. A correction that was refused
    // also sets `error`, but leaves the rows it was refused against in place —
    // so the rows, not the error, decide whether the page has failed.
    if (state.visibleRows.isEmpty && state.error != null) {
      return AppErrorState(
        messageKey: state.error,
        isRetrying: state.isLoading,
        onRetry: () => context.read<PunchReportCubit>().load(),
      );
    }

    if (state.visibleRows.isEmpty) {
      return AppEmptyState(
        icon: Icons.fingerprint,
        title: LangKeys.reportNoRows.tr(),
        subtitle: state.issuesOnly ? LangKeys.reportNoIssues.tr() : null,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.pagePaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PunchReportTotals(state: state),
          const SizedBox(height: AppDimens.cardGap),
          PunchReportPatterns(patterns: state.patterns),
          const SizedBox(height: AppDimens.cardGap),
          GlassCard(
            padding: const EdgeInsets.all(AppDimens.spaceSm),
            child: PunchReportTable(rows: state.visibleRows),
          ),
        ],
      ),
    );
  }
}

/// The page's own shape in grey: the totals strip, the patterns card, then the
/// table — so the three sections do not shuffle into place one after another
/// when the range finishes loading.
class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.pagePaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppStatRowSkeleton(count: 4, cardHeight: 76),
          const SizedBox(height: AppDimens.cardGap),
          const AppCardSkeleton(lines: 2),
          const SizedBox(height: AppDimens.cardGap),
          GlassCard(
            padding: const EdgeInsets.all(AppDimens.spaceSm),
            child: const AppTableSkeleton(rows: 9, columnFlex: _reportColumns),
          ),
        ],
      ),
    );
  }
}
