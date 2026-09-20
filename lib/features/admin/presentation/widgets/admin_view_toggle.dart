import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../cubit/admin_attendance_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminViewToggle extends StatelessWidget {
  const AdminViewToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isMonthly = context.select<AdminAttendanceCubit, bool>(
      (c) => c.state.isMonthlyView,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: LangKeys.dailyView.tr(),
            active: !isMonthly,
            onTap: isMonthly
                ? () => context.read<AdminAttendanceCubit>().toggleView()
                : null,
          ),
          _ToggleButton(
            label: LangKeys.monthlyView.tr(),
            active: isMonthly,
            onTap: !isMonthly
                ? () => context.read<AdminAttendanceCubit>().toggleView()
                : null,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.color.primary : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active
                ? context.color.primaryForeground
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
