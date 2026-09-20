import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/models/shift_model.dart';
import '../cubit/shifts_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Confirms deleting a shift, and says plainly what happens to the people on
/// it — they go back to the default work hours, they are not deleted with it.
void showShiftDeleteDialog(BuildContext context, ShiftModel shift) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ShiftsCubit>(),
      child: _ShiftDeleteDialog(shift: shift),
    ),
  );
}

class _ShiftDeleteDialog extends StatelessWidget {
  const _ShiftDeleteDialog({required this.shift});
  final ShiftModel shift;

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
              LangKeys.shiftDeleteTitle.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '"${shift.name}" (${shift.hours}) — '
              '${LangKeys.shiftDeleteMsg.tr()}',
              style: TextStyle(fontSize: 13, color: faded),
              textAlign: TextAlign.center,
            ),
            // The part an admin cannot see from the list alone, and the reason
            // this is a confirmation rather than a plain delete: those people
            // start being judged by different hours the moment it happens.
            if (shift.inUse > 0) ...[
              const SizedBox(height: 8),
              Text(
                LangKeys.shiftDeleteMoves.tr(args: ['${shift.inUse}']),
                style: TextStyle(
                  fontSize: 11,
                  color: context.color.warningSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
                        final cubit = context.read<ShiftsCubit>();
                        Navigator.pop(context);
                        cubit.remove(shift);
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
