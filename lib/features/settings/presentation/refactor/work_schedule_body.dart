import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/work_schedule_cubit.dart';
import '../../../../core/widgets/app_time_field.dart';
import '../../../../core/widgets/rest_day_picker.dart';
import '../../../../core/style/theme/context_extension.dart';

class WorkScheduleBody extends StatelessWidget {
  const WorkScheduleBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkScheduleCubit, WorkScheduleState>(
      listenWhen: (p, c) => p.error != c.error || p.message != c.message,
      listener: (context, state) {
        if (state.error != null) AppToast.error(context, state.error!.tr());
        if (state.message != null) {
          AppToast.success(context, state.message!.tr());
        }
      },
      builder: (context, state) {
        final cubit = context.read<WorkScheduleCubit>();
        final schedule = state.schedule;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.scheduleTitle.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _hint(context, LangKeys.scheduleHint.tr()),
              const SizedBox(height: 16),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppTimeField(
                      icon: Icons.login,
                      label: LangKeys.scheduleWorkStart.tr(),
                      value: schedule.workStart,
                      onChanged: cubit.setWorkStart,
                    ),
                    _divider(context),
                    AppTimeField(
                      icon: Icons.logout,
                      label: LangKeys.scheduleWorkEnd.tr(),
                      value: schedule.workEnd,
                      onChanged: cubit.setWorkEnd,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _hint(context, LangKeys.scheduleWorkHint.tr()),
              const SizedBox(height: 16),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppTimeField(
                      icon: Icons.more_time,
                      label: LangKeys.scheduleOvertimeStart.tr(),
                      value: schedule.overtimeStart,
                      onChanged: cubit.setOvertimeStart,
                    ),
                    _divider(context),
                    AppTimeField(
                      icon: Icons.timer_off_outlined,
                      label: LangKeys.scheduleOvertimeEnd.tr(),
                      value: schedule.overtimeEnd,
                      onChanged: cubit.setOvertimeEnd,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _hint(context, LangKeys.scheduleOvertimeHint.tr()),
              const SizedBox(height: 20),
              Text(
                LangKeys.restDaysTitle.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              RestDayPicker(
                restDays: schedule.restDays,
                onChanged: cubit.setRestDays,
              ),
              const SizedBox(height: 6),
              _hint(
                context,
                schedule.restDays.isEmpty
                    ? LangKeys.restDaysNone.tr()
                    : LangKeys.restDaysHint.tr(),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: LangKeys.adminSave.tr(),
                icon: Icons.save_outlined,
                onPressed: state.canSave ? cubit.save : null,
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
                    child: Text(
                      LangKeys.scheduleRefreshHint.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
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

  Widget _divider(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
  );
}
