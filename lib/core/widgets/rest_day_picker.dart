import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../style/theme/context_extension.dart';

/// The weekdays a schedule does not work, as seven toggles.
///
/// In core rather than a feature because two screens set them: the company's
/// default hours and each shift's. They have to look and behave identically,
/// or an admin would reasonably wonder whether they mean the same thing.
///
/// Values are [DateTime.weekday] numbers, Monday 1 … Sunday 7. The names come
/// from [DateFormat] in the reader's own locale, so the Arabic build shows
/// Arabic day names without a single key being added.
class RestDayPicker extends StatelessWidget {
  const RestDayPicker({
    super.key,
    required this.restDays,
    required this.onChanged,
    this.locale,
  });

  final Set<int> restDays;
  final ValueChanged<Set<int>> onChanged;

  /// The locale to name the days in. Defaults to the app's current one.
  final String? locale;

  @override
  Widget build(BuildContext context) {
    // Any Monday will do — this is only ever used to get the weekday names in
    // order, never to mean a particular date.
    final reference = DateTime(2024, 1, 1);
    final format = DateFormat(
      'E',
      locale ?? Localizations.localeOf(context).languageCode,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var weekday = 1; weekday <= DateTime.daysPerWeek; weekday++)
          _dayChip(
            context,
            weekday: weekday,
            label: format.format(reference.add(Duration(days: weekday - 1))),
          ),
      ],
    );
  }

  Widget _dayChip(
    BuildContext context, {
    required int weekday,
    required String label,
  }) {
    final selected = restDays.contains(weekday);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final next = {...restDays};
        // Toggling rather than replacing: a rest day is an independent yes or
        // no, and a company that rests on two days should not have to hold a
        // modifier key to say so.
        if (!next.remove(weekday)) next.add(weekday);
        onChanged(next);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? context.color.primary.withValues(alpha: 0.15)
              : scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? context.color.primary.withValues(alpha: 0.6)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? context.color.primary
                : scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
