import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
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
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

void showEmployeeFormSheet(BuildContext context, {EmployeeModel? employee}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.effects.scrim,
    useSafeArea: true,
    // Keeps the card off the screen edges on tablets and desktop instead of
    // stretching a form across the whole width.
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => Padding(
      // The vertical margin is what makes it read as a floating dialog rather
      // than a panel welded to the bottom of the screen.
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceXl,
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<EmployeeManagementCubit>()),
          BlocProvider(
            create: (_) => getIt<EnrollmentCubit>()
              ..seed(
                deviceUserId: employee?.deviceUserId,
                name: employee?.fullName ?? '',
                enrolledFingers: employee?.enrolledFingers ?? const {},
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
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _personalIdCtrl;
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

  /// Inline refusals. The three identity fields are required, and the pair
  /// (surname, full name) must be unique — the data source decides the latter,
  /// which is why it can arrive from the save rather than from this form.
  String? _surnameError;
  String? _nameError;
  String? _personalIdError;
  String? _formError;

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
    _surnameCtrl = TextEditingController(text: e?.surname ?? '');
    _nameCtrl = TextEditingController(text: e?.fullName ?? '');
    _personalIdCtrl = TextEditingController(text: e?.personalId ?? '');
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
    _surnameCtrl.dispose();
    _nameCtrl.dispose();
    _personalIdCtrl.dispose();
    _posCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// The staff number as a fact about the employee rather than a field.
  ///
  /// A disabled text box reads as something that ought to be editable and is
  /// not; this reads as a label, which is what it now is.
  Widget _employeeNumber(BuildContext context) {
    final faded = context.color.mutedForeground;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _idCtrl,
      builder: (context, value, _) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: context.color.muted,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Row(
          children: [
            Icon(Icons.tag, size: 15, color: faded),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              value.text.isEmpty ? '—' : value.text,
              style: AppTextStyles.controlSemiBold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LangKeys.employeeNumberGenerated.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.micro.copyWith(color: faded),
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
    final surname = _surnameCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final personalId = _personalIdCtrl.text.trim();

    // Required: the surname, the full name and the personal id are how a
    // person is told apart on reports and at the terminal. The department is
    // not — "no department" is a real answer at a site with only one.
    final surnameError = surname.isEmpty ? LangKeys.fieldRequired.tr() : null;
    final nameError = name.isEmpty ? LangKeys.fieldRequired.tr() : null;
    final personalIdError = personalId.isEmpty
        ? LangKeys.fieldRequired.tr()
        : null;
    if (surnameError != null || nameError != null || personalIdError != null) {
      setState(() {
        _surnameError = surnameError;
        _nameError = nameError;
        _personalIdError = personalIdError;
      });
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
      _surnameError = null;
      _nameError = null;
      _personalIdError = null;
    });
    final data = {
      // Deliberately absent: an omitted key means "leave it alone" on edit, and
      // on create it tells the data source to take the next number itself.
      'surname': surname,
      'full_name': name,
      'personal_id': personalId,
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
    // Every finger the terminal is known to hold for this person, so the list
    // can show more than a bare "enrolled" badge without asking the device.
    data['enrolled_fingers'] = enrollment.state.enrolledFingers;

    final errorKey = await context.read<EmployeeManagementCubit>().saveEmployee(
      data,
      editId: widget.employee?.id,
    );

    // A refusal keeps the sheet and everything typed in it; closing here would
    // make the admin re-enter the whole form to change one field.
    if (!mounted) return;
    if (errorKey != null) {
      setState(() {
        _saving = false;
        _formError = errorKey.tr();
      });
      return;
    }

    // Keeps the name on the device in step with the name in the app. It is a
    // network round-trip to the terminal, so it must not hold the sheet open.
    unawaited(enrollment.pushName(name));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        // Leaves breathing room above and below even on a short screen; the
        // outer padding already accounts for the rest.
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(color: context.color.border),
        // Plane 4 in the design system — the elevation reserved for dialogs.
        boxShadow: context.effects.shadowXl,
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
                  style: AppTextStyles.subheading.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: AppDimens.iconXl),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _label(LangKeys.adminEmployeeId.tr()),
            _employeeNumber(context),
            const SizedBox(height: 10),
            _label(LangKeys.adminSurname.tr()),
            AppTextField(
              controller: _surnameCtrl,
              hint: LangKeys.adminSurname.tr(),
              errorText: _surnameError,
              onChanged: (_) {
                if (_surnameError != null) {
                  setState(() => _surnameError = null);
                }
              },
            ),
            const SizedBox(height: 10),
            _label(LangKeys.adminFullName.tr()),
            AppTextField(
              controller: _nameCtrl,
              hint: LangKeys.adminFullName.tr(),
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 10),
            _label(LangKeys.adminPersonalId.tr()),
            AppTextField(
              controller: _personalIdCtrl,
              hint: LangKeys.adminPersonalId.tr(),
              keyboardType: TextInputType.number,
              errorText: _personalIdError,
              onChanged: (_) {
                if (_personalIdError != null) {
                  setState(() => _personalIdError = null);
                }
              },
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
            const SizedBox(height: AppDimens.spaceMd),
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
            const SizedBox(height: AppDimens.spaceMd),
            EmployeeFingerprintField(nameOf: () => _nameCtrl.text),
            if (_formError != null) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                _formError!,
                style: AppTextStyles.meta.copyWith(
                  color: context.color.destructive,
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
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
    padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: context.color.mutedForeground,
      ),
    ),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.control),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: AppDimens.spaceXl,
              decoration: BoxDecoration(
                color: value ? context.color.primary : context.color.muted,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
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
