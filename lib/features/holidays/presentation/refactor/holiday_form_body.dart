import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../widgets/holiday_date_row.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Everything on the holiday form: its name, the dates it covers, and whether
/// it is paid.
///
/// Split from the sheet that owns them so the sheet stays about behaviour and
/// this stays about layout. It holds no state — every value is passed in and
/// every change handed back.
class HolidayFormBody extends StatelessWidget {
  const HolidayFormBody({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.start,
    required this.end,
    required this.dayCount,
    required this.isPaid,
    required this.isSaving,
    required this.onNameChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPaidChanged,
    required this.onSave,
  });

  final bool isEditing;
  final TextEditingController nameController;

  final DateTime start;
  final DateTime end;

  /// How many days the range comes to, shown so the admin can check a long
  /// holiday reads the length they meant before saving it.
  final int dayCount;

  final bool isPaid;
  final bool isSaving;

  final ValueChanged<String> onNameChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<bool> onPaidChanged;

  /// Null while the form cannot be saved, which is also what disables the
  /// button.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context),
        const SizedBox(height: 12),
        _label(context, LangKeys.holidayName.tr()),
        AppTextField(
          controller: nameController,
          hint: LangKeys.holidayNameHint.tr(),
          prefixIcon: Icons.event_busy,
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              HolidayDateRow(
                label: LangKeys.holidayStart.tr(),
                icon: Icons.event_available,
                value: start,
                onTap: onPickStart,
              ),
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
              HolidayDateRow(
                label: LangKeys.holidayEnd.tr(),
                icon: Icons.event,
                value: end,
                onTap: onPickEnd,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          LangKeys.holidayDays.tr(args: ['$dayCount']),
          style: TextStyle(
            fontSize: 11,
            color: context.color.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LangKeys.holidayPaid.tr(),
              style: const TextStyle(fontSize: 14),
            ),
            Switch(value: isPaid, onChanged: onPaidChanged),
          ],
        ),
        const SizedBox(height: 18),
        AppPrimaryButton(
          onPressed: onSave,
          label: LangKeys.adminSave.tr(),
          icon: Icons.check,
          isLoading: isSaving,
        ),
      ],
    );
  }

  Widget _header(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        (isEditing ? LangKeys.holidayEdit : LangKeys.holidayAdd).tr(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    ),
  );
}
