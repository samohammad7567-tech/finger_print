import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../cubit/admin_attendance_cubit.dart';

class AdminDatePicker extends StatelessWidget {
  const AdminDatePicker({super.key, required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminAttendanceCubit>().state;
    final cubit = context.read<AdminAttendanceCubit>();

    if (state.isMonthlyView) {
      return _MonthPicker(state: state, cubit: cubit, isArabic: isArabic);
    }
    return _DayPicker(state: state, cubit: cubit, isArabic: isArabic);
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.state,
    required this.cubit,
    required this.isArabic,
  });

  final AdminAttendanceState state;
  final AdminAttendanceCubit cubit;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat(
      'MMMM yyyy',
      isArabic ? 'ar' : 'en',
    ).format(state.selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final prev = DateTime(
              state.selectedDate.year,
              state.selectedDate.month - 1,
            );
            cubit.loadMonth(prev);
          },
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (picked != null) cubit.loadMonth(picked);
          },
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final next = DateTime(
              state.selectedDate.year,
              state.selectedDate.month + 1,
            );
            cubit.loadMonth(next);
          },
        ),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.state,
    required this.cubit,
    required this.isArabic,
  });

  final AdminAttendanceState state;
  final AdminAttendanceCubit cubit;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final label = formatDateLocalized(state.dateStr, isArabic: isArabic);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final prev = state.selectedDate.subtract(const Duration(days: 1));
            cubit.loadDay(prev);
          },
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (picked != null) cubit.loadDay(picked);
          },
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final next = state.selectedDate.add(const Duration(days: 1));
            cubit.loadDay(next);
          },
        ),
      ],
    );
  }
}
