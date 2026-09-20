import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_model.dart';

/// Picks which employee a device user id belongs to.
///
/// Only employees without a terminal id are offered, because the unique index
/// on `device_user_id` would reject the rest anyway.
Future<void> showDeviceEmployeePicker({
  required BuildContext context,
  required List<EmployeeModel> employees,
  required void Function(String employeeId) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _EmployeePickerSheet(employees: employees, onSelected: onSelected),
  );
}

class _EmployeePickerSheet extends StatelessWidget {
  const _EmployeePickerSheet({
    required this.employees,
    required this.onSelected,
  });

  final List<EmployeeModel> employees;
  final void Function(String employeeId) onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                LangKeys.deviceMapToEmployee.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  LangKeys.deviceNoUnmapped.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: employees.length,
                  itemBuilder: (_, index) {
                    final employee = employees[index];
                    return ListTile(
                      title: Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        employee.department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelected(employee.id);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
