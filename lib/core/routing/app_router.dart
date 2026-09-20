import 'package:go_router/go_router.dart';
import '../di/service_locator.dart';
import 'go_router_refresh.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/attendance_detail/presentation/screens/attendance_detail_screen.dart';
import '../../features/check_in/presentation/screens/check_in_screen.dart';
import '../../features/departments/presentation/screens/departments_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_attendance_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/refactor/app_shell.dart';
import '../../features/settings/presentation/screens/work_schedule_screen.dart';
import '../../features/holidays/presentation/screens/holidays_screen.dart';
import '../../features/shifts/presentation/screens/shifts_screen.dart';
import '../../features/admin/presentation/refactor/admin_shell.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/employee_management_screen.dart';
import '../../features/admin/presentation/screens/admin_permissions_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/admin/presentation/screens/admin_notifications_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/punch_report_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/device/presentation/screens/device_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/',
    // Re-runs the redirect whenever the session changes, so signing in or out
    // moves the user without any screen having to navigate.
    refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
    redirect: (context, state) {
      final authState = getIt<AuthCubit>().state;
      final isLoginRoute = state.matchedLocation == '/login';
      final isAdminRoute = state.matchedLocation.startsWith('/admin');

      if (!authState.isLoggedIn && !isLoginRoute) return '/login';
      if (!authState.isLoggedIn && isLoginRoute) return null;

      final isAdmin = authState.isAdmin;
      if (isLoginRoute) return isAdmin ? '/admin' : '/';
      if (isAdmin && !isAdminRoute) return '/admin';
      if (!isAdmin && isAdminRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: '/attendance',
            builder: (_, _) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/attendance/:id',
            builder: (_, state) =>
                AttendanceDetailScreen(employeeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/checkin',
            builder: (_, state) => CheckInScreen(
              initialMode: state.uri.queryParameters['mode'] ?? 'checkin',
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, _, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (_, _) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/employees',
            builder: (_, _) => const EmployeeManagementScreen(),
          ),
          GoRoute(
            path: '/admin/permissions',
            builder: (_, _) => const AdminPermissionsScreen(),
          ),
          GoRoute(
            path: '/admin/attendance',
            builder: (_, _) => const AdminAttendanceScreen(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (_, _) => const AdminReportsScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (_, _) => const AdminNotificationsScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, _) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/punch-report',
            builder: (_, _) => const PunchReportScreen(),
          ),
          GoRoute(
            path: '/admin/work-schedule',
            builder: (_, _) => const WorkScheduleScreen(),
          ),
          GoRoute(
            path: '/admin/shifts',
            builder: (_, _) => const ShiftsScreen(),
          ),
          GoRoute(
            path: '/admin/holidays',
            builder: (_, _) => const HolidaysScreen(),
          ),
          GoRoute(
            path: '/admin/departments',
            builder: (_, _) => const DepartmentsScreen(),
          ),
          GoRoute(
            path: '/admin/device',
            builder: (_, _) => const DeviceScreen(),
          ),
          GoRoute(
            path: '/admin/backup',
            builder: (_, _) => const BackupScreen(),
          ),
        ],
      ),
    ],
  );
}
