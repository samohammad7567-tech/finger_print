import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/di/service_locator.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../departments/presentation/cubit/departments_cubit.dart';
import '../../../departments/presentation/widgets/department_picker_field.dart';
import '../../../shifts/presentation/cubit/shifts_cubit.dart';
import '../../../shifts/presentation/widgets/shift_picker_field.dart';
import '../cubit/employee_management_cubit.dart';
import '../cubit/enrollment_cubit.dart';
import 'employee_fingerprint_field.dart';
import '../../../../core/style/theme/context_extension.dart';

void showEmployeeFormSheet(BuildContext context, {EmployeeModel? employee}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<EmployeeManagementCubit>()),
        BlocProvider(
          create: (_) => getIt<EnrollmentCubit>()
            ..seed(
              deviceUserId: employee?.deviceUserId,
              name: employee?.fullName ?? '',
            ),
        ),
        // Feeds the department picker, and reloads itself when a department is
        // added from inside the form.
        BlocProvider(create: (_) => getIt<DepartmentsCubit>()..load()),
        // Same again for the shift picker: the hours this employee is judged
        // by, and the list of shifts to choose from.
        BlocProvider(create: (_) => getIt<ShiftsCubit>()..load()),
      ],
      child: _EmployeeFormSheet(employee: employee),
    ),
  );
}

class _EmployeeFormSheet extends StatefulWidget {
  const _EmployeeFormSheet({this.employee});
  final EmployeeModel? employee;

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _posCtrl;
  late final TextEditingController _phoneCtrl;

  /// The department name, empty for "no department" — which is both the
  /// default for a new employee and the only choice at a site that never adds
  /// any.
  String _department = '';

  /// The shift id, empty for the company's default work hours — which is both
  /// the default for a new employee and the only choice at a site that never
  /// adds a shift.
  String _shiftId = '';

  bool _hasHousing = false;
  bool _hasTravel = false;
  bool _isActive = true;
  bool _saving = false;

  /// Captured in initState — dispose() runs after the element is unmounted, so
  /// it cannot read the cubit off the context by then.
  late final EnrollmentCubit _enrollment;

  @override
  void initState() {
    super.initState();
    _enrollment = context.read<EnrollmentCubit>();
    final e = widget.employee;
    // The number is the app's to give, not the admin's to choose. It has to
    // stay in one unbroken sequence — deleting somebody closes the gap behind
    // them — and a number typed in by hand would leave a hole that the next
    // renumber silently took back anyway. Shown, never edited.
    if (e == null) _prefillEmployeeNumber();
    _idCtrl = TextEditingController(text: e?.employeeId ?? '');
    _nameCtrl = TextEditingController(text: e?.fullName ?? '');
    _department = e?.department.trim() ?? '';
    _shiftId = e?.shiftId ?? '';
    _posCtrl = TextEditingController(text: e?.position ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _hasHousing = e?.hasHousing ?? false;
    _hasTravel = e?.hasTravelPermission ?? false;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    // Leaving the sheet mid-enrolment would strand the terminal waiting for a
    // finger until its own timeout.
    _enrollment.cancel();
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _posCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// The staff number as a fact about the employee rather than a field.
  ///
  /// A disabled text box reads as something that ought to be editable and is
  /// not; this reads as a label, which is what it now is.
  Widget _employeeNumber(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _idCtrl,
      builder: (context, value, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.tag, size: 15, color: faded),
            const SizedBox(width: 8),
            Text(
              value.text.isEmpty ? '—' : value.text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LangKeys.employeeNumberGenerated.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: faded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prefillEmployeeNumber() async {
    final next = await context
        .read<EmployeeManagementCubit>()
        .nextEmployeeNumber();
    if (mounted && _idCtrl.text.isEmpty) _idCtrl.text = next;
  }

  Future<void> _save() async {
    // The department is no longer required: "no department" is a real answer,
    // and the only one at a site with a single department.
    if (_nameCtrl.text.trim().isEmpty) return;

    // A shift is required as soon as there is one to choose. Which working day
    // somebody is on decides what every one of their punches means, so it is
    // not a field to leave for later — and it is refused here rather than by a
    // disabled button, so the admin is told which answer is missing.
    final hasShifts = context.read<ShiftsCubit>().state.shifts.isNotEmpty;
    if (hasShifts && _shiftId.isEmpty) {
      AppToast.error(context, LangKeys.errorShiftRequired.tr());
      return;
    }

    setState(() => _saving = true);
    final data = {
      // Deliberately absent: an omitted key means "leave it alone" on edit, and
      // on create it tells the data source to take the next number itself.
      'full_name': _nameCtrl.text,
      'department': _department,
      'position': _posCtrl.text,
      'phone': _phoneCtrl.text,
      'has_housing': _hasHousing,
      'has_travel_permission': _hasTravel,
      // Empty means the company default. Sent as null rather than '' so the
      // column holds the same "no shift" the upgrade left every existing
      // employee with, and the fold has one case to resolve instead of two.
      'shift_id': _shiftId.isEmpty ? null : _shiftId,
      'is_active': _isActive,
    };
    // A terminal slot claimed during enrolment is what links this employee to
    // their punches, so it is saved even if the finger scan was abandoned.
    final enrollment = context.read<EnrollmentCubit>();
    final deviceUserId = enrollment.state.deviceUserId;
    if (deviceUserId != null) data['device_user_id'] = deviceUserId;

    await context.read<EmployeeManagementCubit>().saveEmployee(
      data,
      editId: widget.employee?.id,
    );

    // Keeps the name on the device in step with the name in the app.
    await enrollment.pushName(_nameCtrl.text);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.employee != null
                      ? LangKeys.adminEditEmployee.tr()
                      : LangKeys.adminAddEmployee.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _label(LangKeys.adminEmployeeId.tr()),
            _employeeNumber(context),
            const SizedBox(height: 10),
            _label(LangKeys.adminFullName.tr()),
            AppTextField(
              controller: _nameCtrl,
              hint: LangKeys.adminFullName.tr(),
            ),
            const SizedBox(height: 10),
            _label(LangKeys.adminDepartment.tr()),
            DepartmentPickerField(
              value: _department,
              onChanged: (value) => setState(() => _department = value),
            ),
            const SizedBox(height: 10),
            _label(LangKeys.shiftChoose.tr()),
            ShiftPickerField(
              value: _shiftId,
              onChanged: (value) => setState(() => _shiftId = value),
            ),
            const SizedBox(height: 10),
            _label(LangKeys.adminPosition.tr()),
            AppTextField(
              controller: _posCtrl,
              hint: LangKeys.adminPosition.tr(),
            ),
            const SizedBox(height: 10),
            _label(LangKeys.adminPhone.tr()),
            AppTextField(
              controller: _phoneCtrl,
              hint: '+966...',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _toggle(
              LangKeys.adminHasHousing.tr(),
              _hasHousing,
              (v) => setState(() => _hasHousing = v),
            ),
            _toggle(
              LangKeys.adminHasTravel.tr(),
              _hasTravel,
              (v) => setState(() => _hasTravel = v),
            ),
            _toggle(
              LangKeys.adminActiveEmployee.tr(),
              _isActive,
              (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 12),
            EmployeeFingerprintField(nameOf: () => _nameCtrl.text),
            const SizedBox(height: 16),
            AppPrimaryButton(
              onPressed: _saving ? null : _save,
              label: LangKeys.adminSave.tr(),
              icon: Icons.check,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: value ? context.color.primary : context.color.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: context.color.primaryForeground,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
