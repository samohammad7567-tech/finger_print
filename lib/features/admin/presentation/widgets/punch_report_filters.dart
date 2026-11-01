import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../cubit/punch_report_cubit.dart';
import 'punch_issues_toggle.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_dimens.dart';

/// The date, employee and posting filters for the punch report.
///
/// The fixed spans read as tabs — the active one is filled in — while the last
/// two open a picker, one for a single day and one for a range. The employee
/// scope sits beside them: whose department, position and housing flag the
/// table, totals and exports should keep.
class PunchReportFilters extends StatelessWidget {
  const PunchReportFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PunchReportCubit>();
    final state = context.watch<PunchReportCubit>().state;
    final format = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceSm,
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
          _departmentPicker(context, cubit, state),
          _positionPicker(context, cubit, state),
          _housingPicker(context, cubit, state),
          PunchIssuesToggle(state: state),
          if (state.hasEmployeeFilters)
            TextButton.icon(
              onPressed: cubit.clearEmployeeFilters,
              icon: const Icon(
                Icons.filter_alt_off_outlined,
                size: AppDimens.iconMd,
              ),
              label: Text(
                LangKeys.reportClearFilters.tr(),
                style: AppTextStyles.meta,
              ),
            ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              minimumSize: Size.zero,
            ),
            child: Text(label, style: AppTextStyles.meta),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              minimumSize: Size.zero,
              foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
            ),
            child: Text(label, style: AppTextStyles.meta),
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
    return _picker<String>(
      context: context,
      icon: Icons.person_outline,
      value: state.employeeFilter,
      options: [
        (value: '', label: LangKeys.reportAllEmployees.tr()),
        for (final e in state.employees) (value: e.id, label: e.fullName),
      ],
      onChanged: cubit.setEmployee,
    );
  }

  Widget _departmentPicker(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
  ) {
    return _picker<String>(
      context: context,
      icon: Icons.apartment_outlined,
      value: state.departmentFilter,
      options: [
        (value: '', label: LangKeys.reportAllDepartments.tr()),
        for (final name in state.departmentOptions) (value: name, label: name),
      ],
      onChanged: cubit.setDepartment,
    );
  }

  Widget _positionPicker(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
  ) {
    return _picker<String>(
      context: context,
      icon: Icons.badge_outlined,
      value: state.positionFilter,
      options: [
        (value: '', label: LangKeys.reportAllPositions.tr()),
        for (final name in state.positionOptions) (value: name, label: name),
      ],
      onChanged: cubit.setPosition,
    );
  }

  Widget _housingPicker(
    BuildContext context,
    PunchReportCubit cubit,
    PunchReportState state,
  ) {
    return _picker<PunchHousingFilter>(
      context: context,
      icon: Icons.home_outlined,
      value: state.housingFilter,
      options: [
        (
          value: PunchHousingFilter.all,
          label: LangKeys.reportAllHousing.tr(),
        ),
        (
          value: PunchHousingFilter.housed,
          label: LangKeys.reportHousingOnly.tr(),
        ),
        (
          value: PunchHousingFilter.notHoused,
          label: LangKeys.reportNoHousing.tr(),
        ),
      ],
      onChanged: cubit.setHousing,
    );
  }

  /// One compact dropdown, sized to sit in the filter wrap rather than stretch
  /// it. The value is always one of [options]; the state adds a stale current
  /// value back to its choice lists so this cannot assert.
  Widget _picker<T>({
    required BuildContext context,
    required IconData icon,
    required T value,
    required List<({T value, String label})> options,
    required ValueChanged<T> onChanged,
  }) {
    final muted = context.color.mutedForeground;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        decoration: BoxDecoration(
          border: Border.all(color: context.color.border),
          borderRadius: BorderRadius.circular(AppDimens.radius),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            icon: Icon(Icons.expand_more, size: AppDimens.iconMd),
            style: AppTextStyles.meta.copyWith(color: context.color.foreground),
            items: [
              for (final option in options)
                DropdownMenuItem<T>(
                  value: option.value,
                  child: Row(
                    children: [
                      Icon(icon, size: AppDimens.iconSm, color: muted),
                      const SizedBox(width: AppDimens.spaceXs),
                      Expanded(
                        child: Tooltip(
                          message: option.label,
                          waitDuration: const Duration(milliseconds: 500),
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.meta,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (selected) {
              if (selected != null) onChanged(selected);
            },
          ),
        ),
      ),
    );
  }
}
