import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/admin_notifications_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final AdminNotificationsCubit _notifCubit;

  @override
  void initState() {
    super.initState();
    _notifCubit = getIt<AdminNotificationsCubit>()..loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsCubit>().state.isDark;

    // Refresh unread count when shell is built/rebuilt
    _notifCubit.loadUnreadCount();

    return BlocProvider.value(
      value: _notifCubit,
      child: Scaffold(
        appBar: _buildAppBar(context, isDark),
        body: widget.child,
        bottomNavigationBar: _buildBottomNav(context, isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: context.color.topbarBackground,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.color.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.shield,
              size: 16,
              color: context.color.primaryForeground,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.appName.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                LangKeys.adminPanel.tr(),
                style: TextStyle(
                  fontSize: 10,
                  color: context.color.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        BlocBuilder<AdminNotificationsCubit, AdminNotificationsState>(
          builder: (context, state) {
            return IconButton(
              onPressed: () => context.push('/admin/notifications'),
              icon: Badge(
                isLabelVisible: state.unreadCount > 0,
                label: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: context.color.warningSoft,
                child: Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    final location = GoRouterState.of(context).matchedLocation;
    final tabs = [
      ('/admin', Icons.dashboard, LangKeys.adminHome),
      ('/admin/employees', Icons.people, LangKeys.adminEmployees),
      ('/admin/permissions', Icons.description, LangKeys.permits),
      ('/admin/reports', Icons.bar_chart, LangKeys.adminReportsTab),
      ('/admin/punch-report', Icons.fingerprint, LangKeys.reportTab),
      ('/admin/settings', Icons.settings, LangKeys.settings),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.color.toolbarBackground,
        border: Border(top: BorderSide(color: context.color.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.map((tab) {
              final active = location == tab.$1;
              // Expanded, not intrinsic: six tabs have to share whatever width
              // the window has without the labels pushing each other off.
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go(tab.$1),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: active ? context.color.primary : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tab.$2,
                          size: 20,
                          color: active
                              ? context.color.primaryForeground
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.$3.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? context.color.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
