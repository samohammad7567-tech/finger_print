import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/employee_card.dart';
import '../widgets/filter_tabs.dart';
import '../../../../core/widgets/app_text_field.dart';

class AttendanceBody extends StatelessWidget {
  const AttendanceBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AttendanceCubit, AttendanceState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AttendanceCubit>().clearError();
      },
      child: BlocBuilder<AttendanceCubit, AttendanceState>(
        builder: (context, state) {
          final filtered = state.filtered;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LangKeys.attendanceList.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: LangKeys.searchByNameOrId.tr(),
                  prefixIcon: Icons.search,
                  onChanged: (v) =>
                      context.read<AttendanceCubit>().setSearch(v),
                ),
                const SizedBox(height: 12),
                FilterTabs(
                  activeFilter: state.activeFilter,
                  onChanged: (v) =>
                      context.read<AttendanceCubit>().setFilter(v),
                ),
                const SizedBox(height: 8),
                Text(
                  '${filtered.length} ${LangKeys.employees.tr()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async =>
                        context.read<AttendanceCubit>().load(),
                    child: state.isLoading
                        ? _buildShimmer(context)
                        : filtered.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 200,
                                child: Center(
                                  child: Text(
                                    LangKeys.noResults.tr(),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            padding: const EdgeInsets.only(bottom: 16),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => EmployeeCard(
                              employee: filtered[i].employee,
                              record: filtered[i].record,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
