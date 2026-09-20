import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/admin/data/data_source/admin_notifications_local_data_source.dart';
import '../../features/admin/data/data_source/employee_import_excel_data_source.dart';
import '../../features/admin/data/data_source/monthly_punches_excel_data_source.dart';
import '../../features/admin/data/data_source/monthly_report_pdf_data_source.dart';
import '../../features/admin/data/data_source/punch_report_pdf_data_source.dart';
import '../../features/admin/data/repos/admin_notifications_repo.dart';
import '../../features/admin/data/repos/employee_import_repo.dart';
import '../../features/admin/data/repos/monthly_punches_excel_repo.dart';
import '../../features/admin/data/repos/monthly_report_pdf_repo.dart';
import '../../features/admin/data/repos/punch_report_pdf_repo.dart';
import '../../features/admin/presentation/cubit/admin_notifications_cubit.dart';
import '../../features/admin/presentation/cubit/enrollment_cubit.dart';
import '../../features/admin/presentation/cubit/punch_report_cubit.dart';
import '../../features/auth/data/data_source/auth_local_data_source.dart';
import '../../features/auth/data/repos/auth_repo.dart';
import '../../features/auth/presentation/cubit/admin_password_cubit.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/attendance/data/data_source/attendance_local_data_source.dart';
import '../../features/attendance/data/data_source/day_closing_data_source.dart';
import '../../features/attendance/data/repos/attendance_repo.dart';
import '../../features/attendance/data/repos/day_closing_repo.dart';
import '../../features/attendance/presentation/cubit/attendance_cubit.dart';
import '../../features/check_in/presentation/cubit/check_in_cubit.dart';
import '../../features/attendance_detail/presentation/cubit/attendance_detail_cubit.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../features/departments/data/data_source/departments_local_data_source.dart';
import '../../features/departments/data/repos/departments_repo.dart';
import '../../features/departments/presentation/cubit/departments_cubit.dart';
import '../../features/device/data/data_source/device_settings_local_data_source.dart';
import '../../features/device/data/data_source/device_sync_data_source.dart';
import '../../features/device/data/data_source/zk_device_gate.dart';
import '../../features/device/data/data_source/zk_device_data_source.dart';
import '../../features/device/data/data_source/zk_live_capture_data_source.dart';
import '../../features/device/data/data_source/zk_enrollment_data_source.dart';
import '../../features/device/data/repos/device_repo.dart';
import '../../features/device/presentation/cubit/device_cubit.dart';
import '../../features/permissions/data/data_source/permissions_local_data_source.dart';
import '../../features/permissions/data/repos/permissions_repo.dart';
import '../../features/permissions/presentation/cubit/permissions_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/holidays/data/data_source/holidays_local_data_source.dart';
import '../../features/holidays/data/repos/holidays_repo.dart';
import '../../features/holidays/presentation/cubit/holidays_cubit.dart';
import '../../features/settings/data/data_source/settings_local_data_source.dart';
import '../../features/settings/data/data_source/work_schedule_local_data_source.dart';
import '../../features/settings/data/repos/settings_repo.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/shifts/data/data_source/shifts_local_data_source.dart';
import '../../features/shifts/data/repos/shifts_repo.dart';
import '../../features/shifts/presentation/cubit/shifts_cubit.dart';
import '../database/app_database.dart';
import '../storage/token_storage.dart';

final getIt = GetIt.instance;

/// The default account created on a fresh install, so the app is usable before
/// anyone has had a chance to add users.
///
/// The first argument of [String.fromEnvironment] is the *name* of a
/// `--dart-define` key, not the value; the value belongs in `defaultValue`.
/// Override at build time on a real deployment:
///   flutter build windows --dart-define=SEED_ADMIN_PASSWORD=...
///
/// This only runs when the account table is empty — it never overwrites or
/// re-points an account that already exists.
const _seedAdminEmail = String.fromEnvironment(
  'SEED_ADMIN_EMAIL',
  defaultValue: 'mohammadwork199700@gmail.com',
);
const _seedAdminPassword = String.fromEnvironment(
  'SEED_ADMIN_PASSWORD',
  defaultValue: 'mohammadwork199700@gmail.com',
);

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();

  // Infrastructure. The database must be open before any data source that
  // reads from it is constructed.
  final database = AppDatabase();
  await database.init();

  getIt.registerSingleton<AppDatabase>(database);
  getIt.registerLazySingleton(() => TokenStorage(prefs));

  // Data sources
  getIt.registerLazySingleton(
    () => AuthLocalDataSource(getIt<AppDatabase>(), getIt<TokenStorage>()),
  );
  // The schedule reader lets a correction work out what the day now reads
  // as, against the hours in force when it is made.
  getIt.registerLazySingleton(
    () => AttendanceLocalDataSource(
      getIt<AppDatabase>(),
      getIt<WorkScheduleLocalDataSource>().read,
    ),
  );
  getIt.registerLazySingleton(
    () => PermissionsLocalDataSource(getIt<AppDatabase>()),
  );
  // Judges each employee's absence against their own working week, so it
  // needs the company default behind the shifts, as the fold does.
  getIt.registerLazySingleton(
    () => DayClosingDataSource(
      getIt<AppDatabase>(),
      getIt<WorkScheduleLocalDataSource>().read,
    ),
  );
  getIt.registerLazySingleton(
    () => AdminNotificationsLocalDataSource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton(() => PunchReportPdfDataSource());
  getIt.registerLazySingleton(() => MonthlyReportPdfDataSource());
  getIt.registerLazySingleton(() => MonthlyPunchesExcelDataSource());
  getIt.registerLazySingleton(() => EmployeeImportExcelDataSource());
  getIt.registerLazySingleton(() => SettingsLocalDataSource(prefs));
  getIt.registerLazySingleton(() => WorkScheduleLocalDataSource(prefs));

  // ZKTeco terminal
  getIt.registerLazySingleton(() => ZkDeviceGate());
  getIt.registerLazySingleton(() => ZkDeviceDataSource(getIt<ZkDeviceGate>()));
  getIt.registerLazySingleton(
    () => ZkLiveCaptureDataSource(getIt<ZkDeviceGate>()),
  );
  // The fold judges every punch against the admin's working hours, read fresh
  // on each day it rebuilds so a change takes effect on the next sync.
  getIt.registerLazySingleton(
    () => DeviceSyncDataSource(
      getIt<AppDatabase>(),
      getIt<WorkScheduleLocalDataSource>().read,
    ),
  );
  getIt.registerLazySingleton(() => DeviceSettingsLocalDataSource(prefs));
  getIt.registerLazySingleton(
    () => DepartmentsLocalDataSource(getIt<AppDatabase>()),
  );
  // A shift carries only its own four times; where its overtime window sits
  // comes from the company default, read fresh so changing the default moves
  // every shift's overtime with it.
  getIt.registerLazySingleton(
    () => HolidaysLocalDataSource(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton(
    () => ShiftsLocalDataSource(
      getIt<AppDatabase>(),
      getIt<WorkScheduleLocalDataSource>().read,
    ),
  );
  getIt.registerLazySingleton(
    () => ZkEnrollmentDataSource(getIt<ZkDeviceGate>()),
  );

  // Repos
  getIt.registerLazySingleton(() => AuthRepo(getIt<AuthLocalDataSource>()));
  getIt.registerLazySingleton(
    () => AttendanceRepo(getIt<AttendanceLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => PermissionsRepo(getIt<PermissionsLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => AdminNotificationsRepo(getIt<AdminNotificationsLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => PunchReportPdfRepo(getIt<PunchReportPdfDataSource>()),
  );
  getIt.registerLazySingleton(
    () => MonthlyReportPdfRepo(getIt<MonthlyReportPdfDataSource>()),
  );
  getIt.registerLazySingleton(
    () => MonthlyPunchesExcelRepo(getIt<MonthlyPunchesExcelDataSource>()),
  );
  getIt.registerLazySingleton(
    () => EmployeeImportRepo(getIt<EmployeeImportExcelDataSource>()),
  );
  getIt.registerLazySingleton(
    () => DepartmentsRepo(getIt<DepartmentsLocalDataSource>()),
  );
  getIt.registerLazySingleton(() => ShiftsRepo(getIt<ShiftsLocalDataSource>()));
  getIt.registerLazySingleton(
    () => HolidaysRepo(getIt<HolidaysLocalDataSource>()),
  );
  getIt.registerLazySingleton(
    () => DayClosingRepo(
      getIt<DayClosingDataSource>(),
      getIt<HolidaysRepo>(),
      getIt<SettingsLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton(
    () => SettingsRepo(
      getIt<SettingsLocalDataSource>(),
      getIt<WorkScheduleLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton(
    () => DeviceRepo(
      getIt<ZkDeviceDataSource>(),
      getIt<DeviceSyncDataSource>(),
      getIt<DeviceSettingsLocalDataSource>(),
      getIt<ZkEnrollmentDataSource>(),
      getIt<ZkLiveCaptureDataSource>(),
    ),
  );

  // Cubits
  getIt.registerLazySingleton(() => AuthCubit(getIt<AuthRepo>()));
  // A factory: each confirm dialog gets a clean one, so a wrong password from
  // an earlier attempt is not still on screen when the next one opens.
  getIt.registerFactory(() => AdminPasswordCubit(getIt<AuthRepo>()));
  getIt.registerLazySingleton(() => SettingsCubit(getIt<SettingsRepo>()));
  getIt.registerLazySingleton(
    () => AdminNotificationsCubit(getIt<AdminNotificationsRepo>()),
  );
  // A singleton so the auto-sync timer keeps pulling punches while the user is
  // on other screens.
  getIt.registerLazySingleton(
    () => DeviceCubit(
      getIt<DeviceRepo>(),
      getIt<AttendanceRepo>(),
      getIt<DayClosingRepo>(),
    ),
  );
  getIt.registerFactory(
    () => PunchReportCubit(
      getIt<AttendanceRepo>(),
      getIt<DeviceRepo>(),
      getIt<SettingsRepo>(),
      getIt<ShiftsRepo>(),
      getIt<HolidaysRepo>(),
      getIt<PunchReportPdfRepo>(),
      getIt<MonthlyPunchesExcelRepo>(),
    ),
  );
  getIt.registerFactory(
    () => EnrollmentCubit(
      getIt<ZkEnrollmentDataSource>(),
      getIt<DeviceSettingsLocalDataSource>(),
    ),
  );
  getIt.registerFactory(() => DashboardCubit(getIt<AttendanceRepo>()));
  // A factory: the departments screen and every open employee form each hold
  // their own, and the form's has to reload when a department is added from
  // inside it.
  getIt.registerFactory(() => DepartmentsCubit(getIt<DepartmentsRepo>()));
  // A factory too: the shifts screen and every open employee form each hold
  // their own, and the form's has to reload when a shift is added from inside
  // it.
  getIt.registerFactory(() => ShiftsCubit(getIt<ShiftsRepo>()));
  getIt.registerFactory(() => HolidaysCubit(getIt<HolidaysRepo>()));
  getIt.registerFactory(() => AttendanceCubit(getIt<AttendanceRepo>()));
  getIt.registerFactory(
    () => CheckInCubit(
      getIt<AttendanceRepo>(),
      getIt<PermissionsRepo>(),
      getIt<AdminNotificationsRepo>(),
      getIt<ShiftsRepo>(),
    ),
  );
  getIt.registerFactory(() => AttendanceDetailCubit(getIt<AttendanceRepo>()));
  getIt.registerFactory(
    () => PermissionsCubit(getIt<PermissionsRepo>(), getIt<AttendanceRepo>()),
  );
  getIt.registerFactory(
    () => NotificationsCubit(getIt<AttendanceRepo>(), getIt<SettingsRepo>()),
  );

  // A fresh database has no accounts, which would leave nobody able to sign in.
  await getIt<AuthLocalDataSource>().seedDefaultAdmin(
    email: _seedAdminEmail,
    password: _seedAdminPassword,
  );

  // Write down the days nobody came in, for every finished working day since
  // the app last did so. Awaited rather than left running, so the first screen
  // is drawn from complete data — it is a handful of queries and stops at the
  // marker. A failure here must never keep the app from starting: the pass is
  // idempotent and simply runs again next launch.
  try {
    await getIt<DayClosingRepo>().closeFinishedDays();
  } catch (_) {
    // Deliberately swallowed. Nothing the user can do about it at startup.
  }
}
