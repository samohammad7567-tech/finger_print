import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_time_field.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/widgets/admin_password_dialog.dart';
import '../cubit/punch_report_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

/// The admin's one correction of a day's punches.
///
/// Deliberately plain and deliberately blunt: two times, a warning that says
/// this cannot be done twice, and a save. The window it is offered in is the
/// day itself, so there is nothing here to pick a date with.
class PunchCorrectionSheet extends StatefulWidget {
  const PunchCorrectionSheet({super.key, required this.row});

  final PunchReportRow row;

  /// Opens the sheet over [context], carrying the report's cubit into it so
  /// the save lands on the same instance the table is drawn from.
  static Future<void> show(BuildContext context, PunchReportRow row) {
    final cubit = context.read<PunchReportCubit>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: PunchCorrectionSheet(row: row),
      ),
    );
  }

  @override
  State<PunchCorrectionSheet> createState() => _PunchCorrectionSheetState();
}

class _PunchCorrectionSheetState extends State<PunchCorrectionSheet> {
  late String? _checkIn = widget.row.record.checkInTime;
  late String? _checkOut = widget.row.record.checkOutTime;

  bool get _hasATime => _checkIn != null || _checkOut != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Clears the on-screen keyboard, and the picker's own inset.
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LangKeys.reportCorrectTitle.tr(),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.row.employee.fullName}  ·  ${widget.row.record.date}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            _warning(context),
            const SizedBox(height: 12),
            AppTimeField(
              label: LangKeys.reportCheckIn.tr(),
              value: _checkIn,
              icon: Icons.login,
              onChanged: (v) => setState(() => _checkIn = v),
              onCleared: () => setState(() => _checkIn = null),
            ),
            AppTimeField(
              label: LangKeys.reportCheckOut.tr(),
              value: _checkOut,
              icon: Icons.logout,
              onChanged: (v) => setState(() => _checkOut = v),
              onCleared: () => setState(() => _checkOut = null),
            ),
            const SizedBox(height: 20),
            _actions(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Said before the fields, not after them: by the time somebody has picked a
  /// time they have already decided.
  Widget _warning(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.color.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: context.color.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            LangKeys.reportCorrectWarning.tr(),
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _actions(BuildContext context) {
    return BlocBuilder<PunchReportCubit, PunchReportState>(
      buildWhen: (p, c) => p.isCorrecting != c.isCorrecting,
      builder: (context, state) => Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: state.isCorrecting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(LangKeys.cancel.tr()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AppPrimaryButton(
              // Clearing both times would spend the day's one correction on
              // nothing, so there is nothing to save.
              onPressed: _hasATime && !state.isCorrecting ? _save : null,
              isLoading: state.isCorrecting,
              label: LangKeys.reportCorrectSave.tr(),
              icon: Icons.check,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    // Prove it is still the person who signed in before anything is written.
    // The correction is one-shot and goes on the record under their name, so
    // it is worth asking rather than trusting whoever happens to be standing
    // at an unlocked machine. Anything but a confirmed password leaves the
    // sheet open and the day untouched.
    final confirmed = await showAdminPasswordDialog(
      context,
      reason: LangKeys.confirmIdentityCorrection,
    );
    if (!confirmed || !mounted) return;

    final cubit = context.read<PunchReportCubit>();
    final navigator = Navigator.of(context);

    await cubit.correctPunches(
      recordId: widget.row.record.id,
      checkIn: _checkIn,
      checkOut: _checkOut,
      // Who made the correction, for the trail it leaves. Read from the
      // signed-in account rather than typed, so it cannot be another name.
      correctedBy: getIt<AuthCubit>().state.displayName,
    );

    // The report's own listener reports the outcome either way; the sheet has
    // done its part once the write has been attempted.
    if (navigator.mounted) navigator.pop();
  }
}
