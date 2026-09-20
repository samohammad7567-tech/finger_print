import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class EmployeeProfileCard extends StatelessWidget {
  const EmployeeProfileCard({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.color.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                employee.fullName.isNotEmpty
                    ? employee.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: context.color.primaryForeground,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (employee.department.trim().isNotEmpty)
                  Text(
                    employee.department,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (employee.hasHousing)
                      _tag(
                        Icons.home,
                        LangKeys.housing.tr(),
                        context.color.success,
                      ),
                    if (employee.hasTravelPermission)
                      _tag(
                        Icons.flight,
                        LangKeys.travelPerm.tr(),
                        context.color.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
