import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class EmployeeSearch extends StatelessWidget {
  const EmployeeSearch({
    super.key,
    required this.search,
    required this.employees,
    required this.todayRecords,
    required this.disabledReasonFor,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final String search;
  final List<EmployeeModel> employees;
  final Map<String, AttendanceRecordModel> todayRecords;
  final String? Function(String employeeId) disabledReasonFor;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<EmployeeModel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.searchEmployee.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                hint: LangKeys.employeeNameOrId.tr(),
                prefixIcon: Icons.search,
                onChanged: onSearchChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${employees.length} ${LangKeys.employees.tr()}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: employees.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) =>
              _buildEmployeeTile(context, employees[index]),
        ),
      ],
    );
  }

  Widget _buildEmployeeTile(BuildContext context, EmployeeModel emp) {
    final reason = disabledReasonFor(emp.id);
    final isDisabled = reason != null;
    final record = todayRecords[emp.id];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: isDisabled ? null : () => onSelected(emp),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDisabled ? context.color.muted : context.color.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isDisabled
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5)
                        : context.color.primaryForeground,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (emp.department.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      emp.department,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDisabled)
              _buildStatusBadge(context, reason, record)
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String reason,
    AttendanceRecordModel? record,
  ) {
    final (label, color) = _statusInfo(context, reason, record);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason == 'already_checked_in' || reason == 'already_checked_out')
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Icon(Icons.check_circle, size: 14, color: color),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(
    BuildContext context,
    String reason,
    AttendanceRecordModel? record,
  ) {
    switch (reason) {
      case 'already_checked_in':
        return (
          record?.checkInTime ?? LangKeys.checkIn.tr(),
          context.color.success,
        );
      case 'already_checked_out':
        return (
          record?.checkOutTime ?? LangKeys.checkOut.tr(),
          context.color.primary,
        );
      case 'marked_absent':
        return (LangKeys.absent.tr(), context.color.destructive);
      case 'on_leave':
        return (LangKeys.onLeaveStatus.tr(), context.color.infoSoft);
      case 'has_permission':
        return (LangKeys.permission.tr(), context.color.warning);
      default:
        return (
          LangKeys.alreadyRecordedStatus.tr(),
          context.color.subtleForeground,
        );
    }
  }
}
