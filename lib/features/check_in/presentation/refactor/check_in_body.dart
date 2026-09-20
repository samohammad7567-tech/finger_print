import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/di/service_locator.dart';
import '../cubit/check_in_cubit.dart';
import '../cubit/check_in_state.dart';
import '../widgets/mode_selector.dart';
import '../widgets/employee_search.dart';
import '../widgets/check_in_form.dart';
import '../../../../core/style/theme/context_extension.dart';

class CheckInBody extends StatelessWidget {
  const CheckInBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckInCubit, CheckInState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null || (curr.isSuccess && !prev.isSuccess),
      listener: (context, state) {
        if (state.errorMessage != null) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<CheckInCubit>().clearError();
        } else if (state.isSuccess) {
          HapticFeedback.mediumImpact();
        }
      },
      child: BlocBuilder<CheckInCubit, CheckInState>(
        builder: (context, state) {
          return PopScope(
            canPop: state.selected == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                context.read<CheckInCubit>().clearSelection();
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LangKeys.attendanceEntry.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModeSelector(
                    currentMode: state.mode,
                    onChanged: (m) => context.read<CheckInCubit>().setMode(m),
                  ),
                  const SizedBox(height: 16),
                  if (state.selected == null)
                    EmployeeSearch(
                      search: state.search,
                      employees: state.filteredEmployees,
                      todayRecords: state.todayRecords,
                      disabledReasonFor: state.employeeDisabledReason,
                      onSearchChanged: (v) =>
                          context.read<CheckInCubit>().setSearch(v),
                      onSelected: (e) =>
                          context.read<CheckInCubit>().selectEmployee(e),
                    ),
                  if (state.selected != null) ...[
                    GestureDetector(
                      onTap: () =>
                          context.read<CheckInCubit>().clearSelection(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              size: 16,
                              color: context.color.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              LangKeys.backToList.tr(),
                              style: TextStyle(
                                color: context.color.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CheckInForm(
                      employee: state.selected!,
                      time: state.time,
                      notes: state.notes,
                      mode: state.mode,
                      isLoading: state.isLoading,
                      isSuccess: state.isSuccess,
                      onTimeChanged: (t) =>
                          context.read<CheckInCubit>().setTime(t),
                      onNotesChanged: (n) =>
                          context.read<CheckInCubit>().setNotes(n),
                      onSubmit: () {
                        final displayName =
                            getIt<AuthCubit>().state.displayName;
                        context.read<CheckInCubit>().submit(displayName);
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
