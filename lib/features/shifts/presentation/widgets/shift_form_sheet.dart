import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/work_schedule.dart';
import '../../data/models/shift_model.dart';
import '../cubit/shifts_cubit.dart';
import '../refactor/shift_form_body.dart';

/// Adds a shift, or edits [shift] when one is given.
///
/// Returns the id that was stored, so a caller mid-way through the employee
/// form can select the shift it just created. Null when the admin backed out
/// or the shift was refused.
Future<String?> showShiftFormSheet(BuildContext context, {ShiftModel? shift}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<ShiftsCubit>(),
      child: _ShiftFormSheet(shift: shift),
    ),
  );
}

class _ShiftFormSheet extends StatefulWidget {
  const _ShiftFormSheet({this.shift});
  final ShiftModel? shift;

  @override
  State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  late final TextEditingController _nameCtrl;

  late String _startWork;
  late String _endWork;
  late int _lateGrace;
  late int _earlyOutGrace;
  late Set<int> _restDays;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    _nameCtrl = TextEditingController(text: shift?.name ?? '');
    // A new shift starts on the company's own hours, so an admin adding a
    // second shift only has to change the part that differs.
    final fallback = context.read<ShiftsCubit>().state.companyDefault;
    _startWork = shift?.startWork ?? fallback.workStart;
    _endWork = shift?.endWork ?? fallback.workEnd;
    _lateGrace = shift?.lateGraceMinutes ?? 0;
    _earlyOutGrace = shift?.earlyOutGraceMinutes ?? 0;
    // A new shift inherits the company's rest days, so a site where everybody
    // rests on the same days only has to say so once.
    _restDays = {...(shift?.restDays ?? fallback.restDays)};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// What is on the form right now, whether or not it can be saved.
  ShiftModel get _draft => ShiftModel(
    id: widget.shift?.id ?? '',
    name: _nameCtrl.text,
    startWork: _startWork,
    endWork: _endWork,
    lateGraceMinutes: _lateGrace,
    earlyOutGraceMinutes: _earlyOutGrace,
    restDays: _restDays,
  );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final cubit = context.read<ShiftsCubit>();
    final saved = widget.shift == null
        ? await cubit.add(_draft)
        : await cubit.edit(_draft);

    if (!mounted) return;
    // Null means it was refused — a duplicate name or hours that cannot be
    // worked. The sheet stays open with the values still in it so the admin
    // can correct them rather than key them in again.
    if (saved == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final companyDefault = context.select<ShiftsCubit, WorkSchedule>(
      (cubit) => cubit.state.companyDefault,
    );
    final schedule = _draft.scheduleFrom(companyDefault);
    final named = _nameCtrl.text.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ShiftFormBody(
          isEditing: widget.shift != null,
          nameController: _nameCtrl,
          startWork: _startWork,
          endWork: _endWork,
          lateGrace: _lateGrace,
          earlyOutGrace: _earlyOutGrace,
          restDays: _restDays,
          schedule: schedule,
          // Only once they have got as far as naming it — a blank form is not
          // a mistake yet.
          showInvalidHours: named && !schedule.isValid,
          isSaving: _saving,
          onNameChanged: (_) => setState(() {}),
          onStartWork: (v) => setState(() => _startWork = v),
          onEndWork: (v) => setState(() => _endWork = v),
          onLateGrace: (v) => setState(() => _lateGrace = v),
          onEarlyOutGrace: (v) => setState(() => _earlyOutGrace = v),
          onRestDays: (v) => setState(() => _restDays = v),
          onSave: (!_saving && named && schedule.isValid) ? _save : null,
        ),
      ),
    );
  }
}
