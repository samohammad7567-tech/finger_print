import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../utils/attendance_utils.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
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
        horizontal: AppDimens.spaceSm,
        vertical: 2,
      ),
      StatusChipSize.md => const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
    };
    final textStyle = switch (size) {
      StatusChipSize.sm => AppTextStyles.micro,
      StatusChipSize.md => AppTextStyles.captionMedium,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: display.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
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
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            display.labelKey.tr(),
            style: textStyle.copyWith(color: display.color),
          ),
        ],
      ),
    );
  }
}

enum StatusChipSize { sm, md }
