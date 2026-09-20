import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/attendance_record_model.dart';
import '../../data/models/employee_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee, this.record});

  final EmployeeModel employee;
  final AttendanceRecordModel? record;

  @override
  Widget build(BuildContext context) {
    final status = parseStatus(record?.status);
    final hours = calcWorkingHours(record?.checkInTime, record?.checkOutTime);

    return GlassCard(
      onTap: () => context.push('/attendance/${employee.id}'),
      child: Row(
        children: [
          _buildAvatar(context),
          const SizedBox(width: 12),
          Expanded(child: _buildInfo(context, hours)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusChip(status: status, size: StatusChipSize.sm),
              if (record?.isEarlyLeave == true ||
                  record?.status == 'early_leave')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 12,
                        color: context.color.warningSoft,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        LangKeys.earlyLeave.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.color.warningSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.color.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              employee.fullName.isNotEmpty
                  ? employee.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: context.color.primaryForeground,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        if (employee.hasHousing)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: context.color.success,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home,
                size: 10,
                color: context.color.primaryForeground,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, String? hours) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                employee.fullName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (employee.hasTravelPermission)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.flight,
                  size: 12,
                  color: context.color.infoSoft,
                ),
              ),
          ],
        ),
        if (employee.department.trim().isNotEmpty)
          Text(
            employee.department,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 12, color: muted),
                const SizedBox(width: 4),
                Text(
                  record?.checkInTime ?? '--:--',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            if (record?.checkOutTime != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 12, color: muted),
                  const SizedBox(width: 4),
                  Text(
                    record!.checkOutTime!,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            if (hours != null)
              Text(hours, style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ],
    );
  }
}
