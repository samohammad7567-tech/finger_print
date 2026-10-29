import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_compact_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading_overlay.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/employee_management_cubit.dart';
import '../widgets/employee_clash_banner.dart';
import '../widgets/employee_device_fetch_button.dart';
import '../widgets/employee_device_push_button.dart';
import '../widgets/employee_device_push_dialog.dart';
import '../widgets/employee_form_sheet.dart';
import '../widgets/employee_import_button.dart';
import '../widgets/employee_import_result_dialog.dart';
import '../widgets/employee_list_empty.dart';
import '../widgets/employee_list_row.dart';
import '../widgets/employee_match_banner.dart';
import '../widgets/employee_name_clash_dialog.dart';
import '../widgets/employee_restore_dialog.dart';
import 'employee_feedback_text.dart';

class EmployeeManagementBody extends StatefulWidget {
  const EmployeeManagementBody({super.key});

  @override
  State<EmployeeManagementBody> createState() => _EmployeeManagementBodyState();
}

class _EmployeeManagementBodyState extends State<EmployeeManagementBody> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<EmployeeManagementCubit, EmployeeManagementState>(
      listener: _onState,
      child: BlocBuilder<EmployeeManagementCubit, EmployeeManagementState>(
        builder: (context, state) {
          return Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  AppDimens.pagePaddingTop,
                  AppDimens.pagePadding,
                  AppDimens.pagePaddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Header(state: state),
                    const SizedBox(height: AppDimens.spaceMd),
                    _Toolbar(state: state),
                    const SizedBox(height: AppDimens.spaceMd),
                    // Above the search box: it explains a name the admin is
                    // about to go looking for and will not find.
                    EmployeeMatchBanner(count: state.pendingMatchCount),
                    EmployeeClashBanner(count: state.nameClashes.length),
                    AppTextField(
                      hint: LangKeys.adminSearchEmployee.tr(),
                      prefixIcon: Icons.search,
                      onChanged: (v) =>
                          context.read<EmployeeManagementCubit>().setSearch(v),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Expanded(child: _list(context, state)),
                  ],
                ),
              ),
              AppLoadingOverlay.maybe(state.isLoading),
              // Named, because a delete that clears a fingerprint off the
              // terminal can take several seconds on a slow link.
              AppLoadingOverlay.maybe(
                state.isDeleting,
                message: LangKeys.deleteInProgress.tr(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Toasts, and the four dialogs that must fire on the transition rather than
  /// on every rebuild behind them.
  void _onState(BuildContext context, EmployeeManagementState state) {
    if (state.errorKey != null) {
      AppToast.error(context, state.errorKey!.tr());
    }
    if (state.successKey != null) {
      AppToast.success(context, employeeSuccessText(state));
    }

    // The report opens over the list the import has already refreshed, so the
    // admin reads "four skipped" with the new names behind it.
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

    // A push that has been planned but not written. Nothing reaches the
    // terminal until the admin presses send in this dialog.
    final plan = state.pushPlan;
    if (plan != null) showEmployeeDevicePushDialog(context, plan);

    if (state.clashesNeedReview && state.hasNameClashes) {
      context.read<EmployeeManagementCubit>().clashesReviewed();
      showEmployeeNameClashDialog(context);
    }

    if (state.errorKey != null ||
        state.successKey != null ||
        importResult != null) {
      // The cubit is captured before the delay rather than read after it: the
      // old version reached for `context` on the far side of the gap, which is
      // a use-after-dispose waiting for a screen that closes inside half a
      // second.
      final cubit = context.read<EmployeeManagementCubit>();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) cubit.clearFeedback();
      });
    }
  }

  Widget _list(BuildContext context, EmployeeManagementState state) {
    if (state.isLoading) {
      return ListView.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
        itemBuilder: (_, _) =>
            const AppCardSkeleton(lines: 2, height: 52, showHeader: false),
      );
    }

    if (!state.hasEmployees) {
      return EmployeeListEmpty(isImporting: state.isImporting);
    }

    final filtered = state.filtered;
    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: LangKeys.noResults.tr(),
        subtitle: state.search.isEmpty ? null : state.search,
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
      itemBuilder: (_, i) => EmployeeListRow(employee: filtered[i]),
    );
  }
}

/// The title and the headcount under it.
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final EmployeeManagementState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          LangKeys.adminEmployeeMgmt.tr(),
          style: AppTextStyles.heading.copyWith(
            color: context.color.foreground,
          ),
        ),
        Text(
          state.hasEmployees
              ? '${state.employees.length} ${LangKeys.employees.tr()}'
              : LangKeys.noEmployees.tr(),
          style: AppTextStyles.caption.copyWith(
            color: context.color.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Fetch, push, import, add.
///
/// A [Wrap] with the full width to itself, rather than four buttons squeezed
/// in beside the heading: on a narrow window they run to a second line instead
/// of overflowing the row.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state});

  final EmployeeManagementState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isSaving || state.isDeleting;

    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        EmployeeDeviceFetchButton(state: state),
        EmployeeDevicePushButton(state: state),
        EmployeeImportButton(state: state),
        AppCompactButton(
          label: LangKeys.add.tr(),
          icon: Icons.add,
          onPressed: busy ? null : () => showEmployeeFormSheet(context),
        ),
      ],
    );
  }
}
