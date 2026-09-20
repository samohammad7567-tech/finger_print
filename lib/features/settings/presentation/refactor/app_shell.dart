import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';
import '../cubit/settings_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final NotificationsCubit _notifCubit;

  @override
  void initState() {
    super.initState();
    _notifCubit = getIt<NotificationsCubit>()..load();
  }

  @override
  Widget build(BuildContext context) {
    final authState = getIt<AuthCubit>().state;
    final guardName = authState.displayName.isNotEmpty
        ? authState.displayName
        : LangKeys.guard.tr();
    final isDark = context.watch<SettingsCubit>().state.isDark;

    // Refresh notifications when shell is built/rebuilt
    _notifCubit.load();

    return BlocProvider.value(
      value: _notifCubit,
      child: Scaffold(
        appBar: _buildAppBar(context, guardName, isDark),
        body: widget.child,
        bottomNavigationBar: _buildBottomNav(context, isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String guardName,
    bool isDark,
  ) {
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'SA',
                style: TextStyle(
                  color: context.color.primaryForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                guardName,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            final hasNotifs = state.notifications.isNotEmpty;
            return IconButton(
              icon: Badge(
                isLabelVisible: hasNotifs,
                label: Text(
                  '${state.notifications.length}',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: context.color.destructive,
                child: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onPressed: () => context.push('/notifications'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    final location = GoRouterState.of(context).matchedLocation;
    final tabs = [
      ('/', Icons.dashboard, 'dashboard'),
      ('/attendance', Icons.people, 'attendance'),
      ('/checkin', Icons.qr_code, 'check_in_tab'),
      ('/settings', Icons.settings, 'settings'),
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
              return GestureDetector(
                onTap: () => context.go(tab.$1),
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
                      style: TextStyle(
                        fontSize: 10,
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
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
