import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/models/admin_notification_model.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminNotificationsBody extends StatelessWidget {
  const AdminNotificationsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AdminNotificationsCubit, AdminNotificationsState>(
      listenWhen: (prev, curr) => curr.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<AdminNotificationsCubit>().clearError();
      },
      child: BlocBuilder<AdminNotificationsCubit, AdminNotificationsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(LangKeys.adminNotifications.tr()),
              actions: [
                if (state.unreadCount > 0)
                  TextButton(
                    onPressed: () =>
                        context.read<AdminNotificationsCubit>().markAllAsRead(),
                    child: Text(
                      LangKeys.markAllRead.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            body: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          LangKeys.noAdminNotifications.tr(),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildCard(
                      context,
                      state.notifications[index],
                      isArabic,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AdminNotificationModel notification,
    bool isArabic,
  ) {
    return GlassCard(
      onTap: notification.isRead
          ? null
          : () => context.read<AdminNotificationsCubit>().markAsRead(
              notification.id,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (notification.isRead
                          ? context.color.subtleForeground
                          : context.color.warningSoft)
                      .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber,
              size: 20,
              color: notification.isRead
                  ? context.color.subtleForeground
                  : context.color.warningSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.employeeName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic
                      ? 'غادر مبكراً ${notification.earlyLeaveCount} مرات هذا الشهر'
                      : 'Left early ${notification.earlyLeaveCount} times this month',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateLocalized(notification.date, isArabic: isArabic),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
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
