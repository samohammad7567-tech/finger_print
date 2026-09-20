import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/shifts_cubit.dart';
import '../widgets/shift_delete_dialog.dart';
import '../widgets/shift_form_sheet.dart';
import '../widgets/shift_tile.dart';
import '../../../../core/style/theme/context_extension.dart';

class ShiftsBody extends StatelessWidget {
  const ShiftsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShiftsCubit, ShiftsState>(
      listenWhen: (p, c) =>
          p.errorKey != c.errorKey || p.successKey != c.successKey,
      listener: (context, state) {
        if (state.errorKey != null) {
          AppToast.error(context, state.errorKey!.tr());
        }
        if (state.successKey != null) {
          AppToast.success(context, state.successKey!.tr());
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.shiftsTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _hint(context, LangKeys.shiftsHint.tr()),
              const SizedBox(height: 16),
              // The hours anybody without a shift is on. Shown first because
              // it is the shift most of the workforce is usually on, and
              // because a list that opened with "nothing here" would hide the
              // fact that the company already has a working day.
              _defaultCard(context, state),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.isEmpty)
                AppEmptyState(
                  icon: Icons.access_time,
                  title: LangKeys.shiftsEmpty.tr(),
                  subtitle: LangKeys.shiftsEmptyHint.tr(),
                )
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (index, shift) in state.shifts.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        ShiftTile(
                          shift: shift,
                          companyDefault: state.companyDefault,
                          onEdit: () =>
                              showShiftFormSheet(context, shift: shift),
                          onDelete: () => showShiftDeleteDialog(context, shift),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                onPressed: state.isSaving
                    ? null
                    : () => showShiftFormSheet(context),
                label: LangKeys.shiftAdd.tr(),
                icon: Icons.add,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: context.color.warningSoft.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _hint(context, LangKeys.scheduleRefreshHint.tr()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _defaultCard(BuildContext context, ShiftsState state) {
    final schedule = state.companyDefault;
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: context.color.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LangKeys.shiftDefault.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${schedule.workStart} – ${schedule.workEnd}',
                  style: TextStyle(fontSize: 11, color: faded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );
}
