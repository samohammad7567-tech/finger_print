import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/employee_management_cubit.dart';
import '../widgets/employee_form_sheet.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/employee_import_button.dart';
import '../widgets/employee_import_result_dialog.dart';
import '../widgets/employee_match_banner.dart';
import '../widgets/employee_device_fetch_button.dart';
import '../widgets/employee_name_clash_dialog.dart';
import '../widgets/employee_restore_dialog.dart';
import '../../../../core/style/theme/context_extension.dart';

class EmployeeManagementBody extends StatefulWidget {
  const EmployeeManagementBody({super.key});

  @override
  State<EmployeeManagementBody> createState() => _EmployeeManagementBodyState();
}

class _EmployeeManagementBodyState extends State<EmployeeManagementBody> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<EmployeeManagementCubit, EmployeeManagementState>(
      listener: (context, state) {
        // Shown through the app's root overlay rather than as a SnackBar. A
        // SnackBar is painted inside this Scaffold, so anything reported while
        // the employee sheet is open — which is every save — was drawn behind
        // it and timed out unseen.
        if (state.errorKey != null) {
          AppToast.error(context, state.errorKey!.tr());
        }

        if (state.successKey != null) {
          AppToast.success(context, _successText(state));
        }

        // The report opens over the list the import has already refreshed, so
        // the admin reads "four skipped" with the new names behind it.
        final importResult = state.importResult;
        if (importResult != null) {
          showEmployeeImportResultDialog(context, importResult);
        }

        // A fetch the terminal answered and nothing came of. Shown before the
        // clash dialog because it is the more likely reason nothing appeared.
        final fetch = state.deviceFetchResult;
        if (state.deletedNeedReview && fetch != null && fetch.hasDeleted) {
          context.read<EmployeeManagementCubit>().deletedReviewed();
          showEmployeeRestoreDialog(context, fetch);
        }

        // A fetch that turned up names appearing twice. Opened from the
        // listener rather than the builder so it fires once, on the transition,
        // instead of every time the list rebuilds behind it.
        if (state.clashesNeedReview && state.hasNameClashes) {
          context.read<EmployeeManagementCubit>().clashesReviewed();
          showEmployeeNameClashDialog(context);
        }

        // Clear feedback after showing
        if (state.errorKey != null ||
            state.successKey != null ||
            importResult != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.read<EmployeeManagementCubit>().clearFeedback();
            }
          });
        }
      },
      child: BlocBuilder<EmployeeManagementCubit, EmployeeManagementState>(
        builder: (context, state) {
          final filtered = state.filtered;
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LangKeys.adminEmployeeMgmt.tr(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (state.hasEmployees)
                                Text(
                                  '${state.employees.length} ${LangKeys.employees.tr()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                )
                              else
                                Text(
                                  LangKeys.noEmployees.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EmployeeDeviceFetchButton(state: state),
                            const SizedBox(width: 8),
                            EmployeeImportButton(state: state),
                            const SizedBox(width: 8),
                            _addButton(context, state),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Above the search box: it explains a name the admin is
                    // about to go looking for and will not find.
                    EmployeeMatchBanner(count: state.pendingMatchCount),
                    // Stays up until somebody renames one of them: a duplicated
                    // name is not urgent, but it silently makes the list
                    // ambiguous and there is otherwise nothing to say so.
                    if (state.hasNameClashes)
                      _clashBanner(context, state.nameClashes.length),
                    AppTextField(
                      hint: LangKeys.adminSearchEmployee.tr(),
                      prefixIcon: Icons.search,
                      onChanged: (v) =>
                          context.read<EmployeeManagementCubit>().setSearch(v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildListContent(context, state, filtered),
                    ),
                  ],
                ),
              ),

              // Loading overlay
              if (state.isLoading)
                Positioned.fill(
                  child: Container(
                    color: context.effects.scrim,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),

              // Deleting overlay
              if (state.isDeleting)
                Positioned.fill(
                  child: Container(
                    color: context.effects.scrim,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Deleting...',
                            style: TextStyle(
                              color: context.color.primaryForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListContent(
    BuildContext context,
    EmployeeManagementState state,
    List<EmployeeModel> filtered,
  ) {
    if (state.isLoading) {
      return _shimmer(context);
    }

    if (!state.hasEmployees) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: context.color.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              LangKeys.noEmployees.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => showEmployeeFormSheet(context),
              icon: const Icon(Icons.add),
              label: Text(LangKeys.addFirstEmployee.tr()),
            ),
            const SizedBox(height: 8),
            // A first employee is rarely the real job — the admin usually has
            // the whole staff list in a file already.
            TextButton.icon(
              onPressed: state.isImporting
                  ? null
                  : () =>
                        context.read<EmployeeManagementCubit>().importFromExcel(
                          typeLabel: LangKeys.importFileType.tr(),
                          confirmLabel: LangKeys.importEmployees.tr(),
                        ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(LangKeys.importEmployees.tr()),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty && state.search.isNotEmpty) {
      return Center(
        child: Text(
          LangKeys.noResults.tr(),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final emp = filtered[i];
        return Opacity(
          opacity: emp.isActive ? 1.0 : 0.5,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.color.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      emp.fullName.isNotEmpty
                          ? emp.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: context.color.primaryForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (emp.hasHousing)
                            Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.home,
                                size: 12,
                                color: context.color.success,
                              ),
                            ),
                          if (emp.hasTravelPermission)
                            Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.flight,
                                size: 12,
                                color: context.color.primary,
                              ),
                            ),
                          if (emp.deviceUserId != null &&
                              emp.deviceUserId!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.fingerprint,
                                size: 12,
                                color: context.color.primary,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        // "No department" is an ordinary choice, so the
                        // separator only appears when there is something on
                        // both sides of it.
                        [
                          if (emp.department.trim().isNotEmpty) emp.department,
                          if ((emp.employeeId ?? '').isNotEmpty)
                            emp.employeeId!,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    emp.isActive ? Icons.person : Icons.person_off,
                    size: 18,
                    color: emp.isActive
                        ? context.color.success
                        : context.color.subtleForeground,
                  ),
                  onPressed: () =>
                      context.read<EmployeeManagementCubit>().toggleActive(emp),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: context.color.primary,
                  ),
                  onPressed: () =>
                      showEmployeeFormSheet(context, employee: emp),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    size: 18,
                    color: context.color.destructive,
                  ),
                  onPressed: () => showDeleteConfirmDialog(context, emp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A fetch says what it did rather than only that it finished: an admin who
  /// presses the button and sees nothing new appear needs to be told whether
  /// that is because the terminal held people back or because there was nothing
  /// to add.
  String _successText(EmployeeManagementState state) {
    final base = state.successKey!.tr();
    final result = state.deviceFetchResult;
    if (result == null) return base;

    final parts = [
      '${LangKeys.deviceFetchRead.tr()}: ${result.readFromDevice}',
      '${LangKeys.deviceFetchCreated.tr()}: ${result.created}',
      if (result.pending > 0)
        '${LangKeys.deviceFetchHeld.tr()}: ${result.pending}',
      if (result.hasDeleted)
        '${LangKeys.deviceFetchDeleted.tr()}: ${result.deleted.length}',
    ];
    return '$base · ${parts.join(' · ')}';
  }

  Widget _clashBanner(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showEmployeeNameClashDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.color.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.color.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 18,
                  color: context.color.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LangKeys.clashBanner.tr(args: ['$count']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.color.warning,
                    ),
                  ),
                ),
                Text(
                  LangKeys.clashReview.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.color.warning,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.color.warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context, EmployeeManagementState state) {
    return GestureDetector(
      onTap: state.isSaving || state.isDeleting
          ? null
          : () => showEmployeeFormSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: state.isSaving || state.isDeleting
              ? context.color.muted
              : context.color.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: context.color.primaryForeground),
            const SizedBox(width: 4),
            Text(
              LangKeys.add.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.color.primaryForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 64,
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
