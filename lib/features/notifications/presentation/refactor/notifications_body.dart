import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/glass_card.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import '../../../../core/style/theme/context_extension.dart';

class NotificationsBody extends StatelessWidget {
  const NotificationsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    LangKeys.notifications.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state.notifications.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: context.color.destructive,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${state.notifications.length}',
                          style: TextStyle(
                            color: context.color.primaryForeground,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.isLoading
                    ? _buildShimmer(context)
                    : state.notifications.isEmpty
                    ? AppEmptyState(
                        icon: Icons.check_circle,
                        title: LangKeys.noAlerts.tr(),
                        subtitle: LangKeys.everythingGood.tr(),
                        iconColor: context.color.success,
                      )
                    : ListView.separated(
                        itemCount: state.notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (_, i) {
                          final n = state.notifications[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _typeColor(
                                      context,
                                      n.type,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _typeColor(
                                        context,
                                        n.type,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(
                                    n.icon,
                                    size: 20,
                                    color: _typeColor(context, n.type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title.tr(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        n.body,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (n.time != null)
                                  Text(
                                    n.time!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// The token a notification's semantic `type` resolves to.
///
/// The cubit names the meaning ('warning', 'danger'); choosing the colour is
/// the view's job, which is what keeps BuildContext out of the state layer.
Color _typeColor(BuildContext context, String type) => switch (type) {
  'danger' => context.color.destructive,
  'warning' => context.color.warning,
  'success' => context.color.success,
  _ => context.color.infoSoft,
};
