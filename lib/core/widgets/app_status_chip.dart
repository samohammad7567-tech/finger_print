import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../utils/attendance_utils.dart';
import '../style/theme/context_extension.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.status,
    this.size = StatusChipSize.md,
  });

  final AttendanceStatus status;
  final StatusChipSize size;

  @override
  Widget build(BuildContext context) {
    final display = getStatusDisplay(status, context.color);
    final padding = switch (size) {
      StatusChipSize.sm => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      StatusChipSize.md => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
    };
    final fontSize = switch (size) {
      StatusChipSize.sm => 10.0,
      StatusChipSize.md => 12.0,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: display.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: display.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: display.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            display.labelKey.tr(),
            style: TextStyle(
              color: display.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusChipSize { sm, md }
