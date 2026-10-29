import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_import_models.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../cubit/employee_management_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_wide_dialog.dart';
import '../../../../core/widgets/app_tinted_pill.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

/// Shows every name that now appears twice in the staff list, and lets the
/// admin write one that tells the two apart.
///
/// The app deliberately stops here rather than deciding. When both records are
/// enrolled on the terminal under different ids they are certainly two people —
/// a fingerprint cannot be shared — and merging them would destroy one of their
/// attendance histories. When only one is enrolled it may be the same person
/// twice, but only somebody who knows the staff can say. Either way the useful
/// thing the app can offer is a rename, so the list stops being ambiguous.
Future<void> showEmployeeNameClashDialog(BuildContext context) {
  final cubit = context.read<EmployeeManagementCubit>();

  return showDialog<void>(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _NameClashDialog()),
  );
}

class _NameClashDialog extends StatelessWidget {
  const _NameClashDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeManagementCubit, EmployeeManagementState>(
      builder: (context, state) {
        final clashes = state.nameClashes;

        return AppWideDialog(
          title: LangKeys.clashTitle.tr(),
          icon: Icons.people_alt_outlined,
          iconColor: context.color.warningSoft,
          // The resolved state is a single centred line; only the list of
          // clashes needs to scroll.
          scrollable: false,
          content: clashes.isEmpty
              ? _resolved(context)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LangKeys.clashHint.tr(),
                        style: AppTextStyles.caption.copyWith(
                          color: context.color.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...clashes.map((c) => _ClashGroup(clash: c)),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LangKeys.close.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _resolved(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: AppDimens.iconXl,
          color: context.color.success,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(child: Text(LangKeys.clashAllResolved.tr())),
      ],
    ),
  );
}

class _ClashGroup extends StatelessWidget {
  const _ClashGroup({required this.clash});

  final EmployeeNameClash clash;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.color.muted,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: context.color.warningSoft.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.clashSharedBy.tr(
              args: [
                '${clash.employees.length}',
                clash.employees.first.fullName,
              ],
            ),
            style: AppTextStyles.bodySemiBold,
          ),
          const SizedBox(height: 2),
          Text(
            // Two fingerprints cannot belong to one person, so this pair needs
            // no deciding — only a name that separates them.
            (clash.isDefinitelyDistinct
                    ? LangKeys.clashCertainlyDistinct
                    : LangKeys.clashMayBeSame)
                .tr(),
            style: AppTextStyles.meta.copyWith(
              color: clash.isDefinitelyDistinct
                  ? context.color.warningSoft
                  : context.color.mutedForeground,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...clash.employees.map((e) => _ClashRow(employee: e)),
        ],
      ),
    );
  }
}

class _ClashRow extends StatefulWidget {
  const _ClashRow({required this.employee});

  final EmployeeModel employee;

  @override
  State<_ClashRow> createState() => _ClashRowState();
}

class _ClashRowState extends State<_ClashRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.employee.fullName,
  );
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty || name == widget.employee.fullName) {
      setState(() => _editing = false);
      return;
    }
    context.read<EmployeeManagementCubit>().renameEmployee(
      widget.employee.id,
      name,
    );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final enrolled = (employee.deviceUserId ?? '').isNotEmpty;
    final faded = context.color.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppTintedPill(
            label: employee.employeeId ?? '—',
            color: context.color.primary,
            fontWeight: FontWeight.w700,
            radius: 6,
            tintAlpha: 0.12,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    style: AppTextStyles.body,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        [
                          if (employee.department.isNotEmpty)
                            employee.department,
                          if (enrolled)
                            LangKeys.clashEnrolledAs.tr(
                              args: [employee.deviceUserId!],
                            )
                          else
                            LangKeys.clashNotEnrolled.tr(),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro.copyWith(
                          color: enrolled ? context.color.primary : faded,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 6),
          if (_editing)
            TextButton(
              onPressed: _save,
              child: Text(LangKeys.save.tr(), style: AppTextStyles.meta),
            )
          else
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit, size: AppDimens.iconSm),
              style: TextButton.styleFrom(foregroundColor: faded),
              label: Text(LangKeys.clashRename.tr(), style: AppTextStyles.meta),
            ),
        ],
      ),
    );
  }
}
