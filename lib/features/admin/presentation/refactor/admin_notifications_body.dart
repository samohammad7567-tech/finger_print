import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/style/theme/app_dimens.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_card_skeleton.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../widgets/admin_notification_card.dart';

/// The early-leave alerts, newest first.
///
/// Used to wrap itself in a second [Scaffold] with its own [AppBar], which the
/// admin shell already supplies — so the page carried two title bars. It now
/// uses [AppPageHeader], the way the other six pushed admin pages do.
class AdminNotificationsBody extends StatelessWidget {
  const AdminNotificationsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<SettingsCubit>().state.isArabic;

    return BlocListener<AdminNotificationsCubit, AdminNotificationsState>(
      listenWhen: (prev, curr) => curr.error != prev.error,
      // Translated here and left on the state: it is also what the page
      // renders when the load brought back nothing.
      listener: (context, state) {
        if (state.error != null) AppToast.error(context, state.error!.tr());
      },
      child: BlocBuilder<AdminNotificationsCubit, AdminNotificationsState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  AppDimens.pagePaddingTop,
                  AppDimens.pagePadding,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AppPageHeader(
                        title: LangKeys.adminNotifications.tr(),
                        fallbackLocation: '/admin',
                      ),
                    ),
                    if (state.unreadCount > 0)
                      TextButton(
                        onPressed: () => context
                            .read<AdminNotificationsCubit>()
                            .markAllAsRead(),
                        child: Text(
                          LangKeys.markAllRead.tr(),
                          style: AppTextStyles.controlSemiBold.copyWith(
                            color: context.color.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _content(context, state, isArabic)),
            ],
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AdminNotificationsState state,
    bool isArabic,
  ) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimens.pagePadding),
        child: Column(
          children: <Widget>[
            AppCardSkeleton(lines: 2, height: 78),
            SizedBox(height: AppDimens.spaceSm),
            AppCardSkeleton(lines: 2, height: 78),
            SizedBox(height: AppDimens.spaceSm),
            AppCardSkeleton(lines: 2, height: 78),
          ],
        ),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return AppErrorState(
        messageKey: state.error,
        onRetry: () => context.read<AdminNotificationsCubit>().load(),
      );
    }

    if (state.notifications.isEmpty) {
      return AppEmptyState(
        icon: Icons.notifications_none,
        title: LangKeys.noAdminNotifications.tr(),
        subtitle: LangKeys.everythingGood.tr(),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      itemCount: state.notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
      itemBuilder: (context, index) => AdminNotificationCard(
        notification: state.notifications[index],
        isArabic: isArabic,
      ),
    );
  }
}
