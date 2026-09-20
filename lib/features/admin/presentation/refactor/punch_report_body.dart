import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/punch_report_cubit.dart';
import '../widgets/punch_report_filters.dart';
import '../widgets/punch_report_header.dart';
import '../widgets/punch_report_patterns.dart';
import '../widgets/punch_report_table.dart';
import '../widgets/punch_report_totals.dart';

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
          children: [
            PunchReportHeader(state: state),
            const PunchReportFilters(),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.visibleRows.isEmpty
                  ? _empty(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PunchReportTotals(state: state),
                          const SizedBox(height: 12),
                          PunchReportPatterns(patterns: state.patterns),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(8),
                            child: PunchReportTable(rows: state.visibleRows),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        LangKeys.reportNoRows.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}
