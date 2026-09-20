import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AddPermissionSheet extends StatefulWidget {
  const AddPermissionSheet({
    super.key,
    required this.employees,
    required this.isSaving,
    required this.onClose,
    required this.onSave,
  });

  final List<EmployeeModel> employees;
  final bool isSaving;
  final VoidCallback onClose;
  final void Function({
    required String employeeId,
    required String employeeName,
    required String permissionType,
    required String date,
    String? reason,
    String? approvedBy,
  })
  onSave;

  @override
  State<AddPermissionSheet> createState() => _AddPermissionSheetState();
}

class _AddPermissionSheetState extends State<AddPermissionSheet> {
  String? _employeeId;
  String _permType = 'travel_permission';
  late String _date;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = getTodayDate();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  /// The permission types offered, with the colour each one carries.
  /// Built per call so the colours follow the active theme.
  List<(String, IconData, Color, String)> _permTypes(BuildContext context) => [
    (
      'travel_permission',
      Icons.flight,
      context.color.infoSoft,
      'travel_permission_type',
    ),
    (
      'housing_early_leave',
      Icons.home,
      context.color.success,
      'housing_early_leave',
    ),
    (
      'approved_early_departure',
      Icons.access_time,
      context.color.warning,
      'approved_early_departure',
    ),
    ('vacation', Icons.calendar_today, context.color.primary, 'vacation'),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: context.effects.scrim,
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildEmployeeDropdown(),
                    const SizedBox(height: 16),
                    _buildPermTypeSelector(),
                    const SizedBox(height: 16),
                    _buildDateField(),
                    const SizedBox(height: 16),
                    _buildReasonField(),
                    const SizedBox(height: 20),
                    _buildSubmit(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          LangKeys.addNewPermission.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LangKeys.employee.tr(), style: _labelStyle()),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _employeeId,
              hint: Text(
                LangKeys.selectEmployee.tr(),
                style: const TextStyle(fontSize: 14),
              ),
              isExpanded: true,
              items: widget.employees
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        e.fullName,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _employeeId = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LangKeys.permissionType.tr(), style: _labelStyle()),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3,
          children: _permTypes(context).map((pt) {
            final active = _permType == pt.$1;
            return GestureDetector(
              onTap: () => setState(() => _permType = pt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(pt.$2, size: 16, color: pt.$3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pt.$4.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LangKeys.date.tr(), style: _labelStyle()),
        const SizedBox(height: 4),
        AppTextField(
          hint: _date,
          prefixIcon: Icons.calendar_today,
          readOnly: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() {
                _date =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LangKeys.reason.tr(), style: _labelStyle()),
        const SizedBox(height: 4),
        AppTextField(
          controller: _reasonCtrl,
          hint: LangKeys.reasonPlaceholder.tr(),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSubmit() {
    return AppPrimaryButton(
      onPressed: _employeeId == null
          ? null
          : () {
              final emp = widget.employees.firstWhere(
                (e) => e.id == _employeeId,
              );
              final displayName = getIt<AuthCubit>().state.displayName;
              widget.onSave(
                employeeId: _employeeId!,
                employeeName: emp.fullName,
                permissionType: _permType,
                date: _date,
                reason: _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : null,
                approvedBy: displayName,
              );
            },
      label: LangKeys.savePermission.tr(),
      icon: Icons.check,
      isLoading: widget.isSaving,
    );
  }

  TextStyle _labelStyle() => TextStyle(
    fontSize: 12,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
  );
}
