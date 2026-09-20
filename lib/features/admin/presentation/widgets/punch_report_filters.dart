import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/punch_report_cubit.dart';
import 'punch_issues_toggle.dart';

/// Date filters and the employee filter for the punch report.
///
/// The fixed spans read as tabs — the active one is filled in — while the last
/// two open a picker, one for a single day and one for a range.
class PunchReportFilters extends StatelessWidget {
  const PunchReportFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PunchReportCubit>();
    final state = context.watch<PunchReportCubit>().state;
    final format = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _tab(
            context,
            LangKeys.reportToday.tr(),
            state.preset == PunchRangePreset.today,
            cubit.showToday,
          ),
          _tab(
            context,
            LangKeys.adminLast7Days.tr(),
            state.preset == PunchRangePreset.last7Days,
            cubit.showLast7Days,
          ),
          _tab(
            context,
            LangKeys.reportThisMonth.tr(),
            state.preset == PunchRangePreset.thisMonth,
            cubit.showThisMonth,
          ),
          _tab(
            context,
            LangKeys.reportLastMonth.tr(),
            state.preset == PunchRangePreset.lastMonth,
            cubit.showLastMonth,
          ),
          _dayButton(context, cubit, state, format),
          _rangeButton(context, cubit, state, format),
          _employeePicker(context, cubit, state),
          PunchIssuesToggle(state: state),
        ],
      ),
    );
  }

  /// [onTap] is null when there is nothing to select — the issues filter with
  /// no issues in range — which is also what greys the button out.
  Widget _tab(
    BuildContext context,
    String label,
    bool active,
    VoidCallback? onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return active
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(label, style: const TextStyle(fontSize: 11)),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
            ),
            child: Text(label, style: const TextStyle(fontSize: 11)),
          );
  }

  /// One chosen date. Shows that date once picked, so it is clear which day is
  /// on screen without reading the range.
  Widget _dayButton(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
    DateFormat format,
  ) {
    final active = state.preset == PunchRangePreset.day;
    return _tab(
      context,
      active
          ? '${LangKeys.reportPickDay.tr()}: ${format.format(state.start)}'
          : LangKeys.reportPickDay.tr(),
      active,
      () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: state.start,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) cubit.showDay(picked);
      },
    );
  }

  Widget _rangeButton(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
    DateFormat format,
  ) {
    final active = state.preset == PunchRangePreset.custom;
    return _tab(
      context,
      active
          ? '${format.format(state.start)}  →  ${format.format(state.end)}'
          : LangKeys.reportRange.tr(),
      active,
      () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          initialDateRange: DateTimeRange(start: state.start, end: state.end),
        );
        if (picked != null) cubit.setRange(picked.start, picked.end);
      },
    );
  }

  Widget _employeePicker(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
  ) {
    return DropdownButton<String>(
      value: state.employeeFilter,
      underline: const SizedBox.shrink(),
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            LangKeys.reportAllEmployees.tr(),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        ...state.employees.map(
          (e) => DropdownMenuItem(
            value: e.id,
            child: Text(
              e.fullName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
      onChanged: (value) => cubit.setEmployee(value ?? ''),
    );
  }
}
