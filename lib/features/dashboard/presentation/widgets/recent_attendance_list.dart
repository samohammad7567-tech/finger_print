import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_status_chip.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class RecentAttendanceList extends StatelessWidget {
  const RecentAttendanceList({
    super.key,
    required this.records,
    required this.isLoading,
  });

  final List<AttendanceRecordModel> records;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
    }

    if (records.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            LangKeys.noRecordsToday.tr(),
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Column(
      children: records
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.color.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (r.employeeName != null && r.employeeName!.isNotEmpty)
                              ? r.employeeName![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: context.color.primaryForeground,
                            fontSize: 12,
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
                            r.employeeName ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r.checkInTime ?? '--:--',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppStatusChip(
                      status: parseStatus(r.status),
                      size: StatusChipSize.sm,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
