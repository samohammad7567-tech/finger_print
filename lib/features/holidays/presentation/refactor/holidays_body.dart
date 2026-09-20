import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/holidays_cubit.dart';
import '../widgets/holiday_delete_dialog.dart';
import '../widgets/holiday_form_sheet.dart';
import '../widgets/holiday_tile.dart';
import '../../../../core/style/theme/context_extension.dart';

class HolidaysBody extends StatelessWidget {
  const HolidaysBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HolidaysCubit, HolidaysState>(
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
                LangKeys.holidaysTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _hint(context, LangKeys.holidaysHint.tr()),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.isEmpty)
                AppEmptyState(
                  icon: Icons.event_busy,
                  title: LangKeys.holidaysEmpty.tr(),
                  subtitle: LangKeys.holidaysEmptyHint.tr(),
                )
              else ...[
                // The tally first: an admin filling in a year needs to know
                // whether it looks complete, and counting rows by eye is
                // exactly the thing a screen should do for them.
                Text(
                  LangKeys.holidaysTotal.tr(
                    args: ['${state.holidays.length}', '${state.totalDays}'],
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.color.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (index, holiday)
                          in state.holidays.indexed) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        HolidayTile(
                          holiday: holiday,
                          onEdit: () =>
                              showHolidayFormSheet(context, holiday: holiday),
                          onDelete: () =>
                              showHolidayDeleteDialog(context, holiday),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppPrimaryButton(
                onPressed: state.isSaving
                    ? null
                    : () => showHolidayFormSheet(context),
                label: LangKeys.holidayAdd.tr(),
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

  Widget _hint(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    ),
  );
}
