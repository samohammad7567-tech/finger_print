import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/holiday_model.dart';
import '../cubit/holidays_cubit.dart';
import '../refactor/holiday_form_body.dart';

/// Adds a holiday, or edits [holiday] when one is given.
///
/// Returns the id that was stored, or null when the admin backed out or the
/// holiday was refused.
Future<String?> showHolidayFormSheet(
  BuildContext context, {
  HolidayModel? holiday,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<HolidaysCubit>(),
      child: _HolidayFormSheet(holiday: holiday),
    ),
  );
}

class _HolidayFormSheet extends StatefulWidget {
  const _HolidayFormSheet({this.holiday});
  final HolidayModel? holiday;

  @override
  State<_HolidayFormSheet> createState() => _HolidayFormSheetState();
}

class _HolidayFormSheetState extends State<_HolidayFormSheet> {
  late final TextEditingController _nameCtrl;
  late DateTime _start;
  late DateTime _end;
  late bool _isPaid;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final holiday = widget.holiday;
    _nameCtrl = TextEditingController(text: holiday?.name ?? '');
    // A new holiday starts as today, one day long — the shape most of them
    // are, and the smallest thing to correct when it is not.
    final today = DateTime.now();
    _start = holiday?.start ?? DateTime(today.year, today.month, today.day);
    _end = holiday?.end ?? _start;
    _isPaid = holiday?.isPaid ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// What is on the form right now, whether or not it can be saved.
  HolidayModel get _draft => HolidayModel(
    id: widget.holiday?.id ?? '',
    name: _nameCtrl.text,
    startDate: HolidayModel.isoDate(_start),
    endDate: HolidayModel.isoDate(_end),
    isPaid: _isPaid,
  );

  Future<void> _pick({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _start = picked;
        // Dragging the first day past the last is a correction in progress,
        // not a mistake to scold them for — the other end follows it along
        // rather than leaving a range that covers nothing.
        if (_end.isBefore(_start)) _end = picked;
      } else {
        _end = picked;
        if (_end.isBefore(_start)) _start = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final cubit = context.read<HolidaysCubit>();
    final saved = widget.holiday == null
        ? await cubit.add(_draft)
        : await cubit.edit(_draft);

    if (!mounted) return;
    // Null means it was refused. The sheet stays open with the values still in
    // it so the admin can correct them rather than key them in again.
    if (saved == null) {
      setState(() => _saving = false);
      return;
    }
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;

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
        child: HolidayFormBody(
          isEditing: widget.holiday != null,
          nameController: _nameCtrl,
          start: _start,
          end: _end,
          dayCount: draft.dayCount,
          isPaid: _isPaid,
          isSaving: _saving,
          onNameChanged: (_) => setState(() {}),
          onPickStart: () => _pick(isStart: true),
          onPickEnd: () => _pick(isStart: false),
          onPaidChanged: (v) => setState(() => _isPaid = v),
          onSave: (!_saving && draft.isValid) ? _save : null,
        ),
      ),
    );
  }
}
