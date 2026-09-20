import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/models/holiday_model.dart';
import '../cubit/holidays_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Confirms deleting a holiday, and says what it means: those dates start
/// counting as ordinary working days again, in every report.
void showHolidayDeleteDialog(BuildContext context, HolidayModel holiday) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<HolidaysCubit>(),
      child: _HolidayDeleteDialog(holiday: holiday),
    ),
  );
}

class _HolidayDeleteDialog extends StatelessWidget {
  const _HolidayDeleteDialog({required this.holiday});
  final HolidayModel holiday;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.color.destructive,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.warning_amber,
                size: 28,
                color: context.color.primaryForeground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LangKeys.holidayDeleteTitle.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"${holiday.name}" — '
              '${LangKeys.holidayDays.tr(args: ['${holiday.dayCount}'])}',
              style: TextStyle(fontSize: 13, color: faded),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              LangKeys.holidayDeleteMsg.tr(),
              style: TextStyle(fontSize: 11, color: context.color.warningSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(LangKeys.adminCancel.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.color.destructive,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: MaterialButton(
                      onPressed: () {
                        final cubit = context.read<HolidaysCubit>();
                        Navigator.pop(context);
                        cubit.remove(holiday);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        LangKeys.adminDelete.tr(),
                        style: TextStyle(
                          color: context.color.primaryForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
