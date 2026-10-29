import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/app_icon_badge.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/admin_notification_model.dart';
import '../cubit/admin_notifications_cubit.dart';

/// One early-leave alert: who, how many times, and when it was raised.
///
/// Tapping an unread one marks it read. A read one is not tappable — there is
/// nothing left to do to it, and an affordance that does nothing is worse than
/// none.
class AdminNotificationCard extends StatelessWidget {
  const AdminNotificationCard({
    super.key,
    required this.notification,
    required this.isArabic,
  });

  final AdminNotificationModel notification;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final read = notification.isRead;

    return GlassCard(
      onTap: read
          ? null
          : () => context.read<AdminNotificationsCubit>().markAsRead(
              notification.id,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppIconBadge.tinted(
            icon: Icons.warning_amber,
            color: read
                ? context.color.subtleForeground
                : context.color.warningSoft,
            size: 32,
            radius: AppDimens.radius,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  notification.employeeName,
                  style:
                      (read ? AppTextStyles.body : AppTextStyles.bodySemiBold)
                          .copyWith(color: context.color.foreground),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  // Was two hand-written sentences, one per language, inlined
                  // in the widget. The count is an argument now, so a third
                  // language costs a JSON entry rather than an `if`.
                  LangKeys.notificationEarlyLeaveCount.tr(
                    namedArgs: <String, String>{
                      'count': '${notification.earlyLeaveCount}',
                    },
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: context.color.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  formatDateLocalized(notification.date, isArabic: isArabic),
                  style: AppTextStyles.meta.copyWith(
                    color: context.color.subtleForeground,
                  ),
                ),
              ],
            ),
          ),
          if (!read)
            Container(
              width: AppDimens.spaceSm,
              height: AppDimens.spaceSm,
              decoration: BoxDecoration(
                color: context.color.warningSoft,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
