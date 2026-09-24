import '../../data/data_source/zk_device_data_source.dart';
import '../../data/models/device_settings_model.dart';
import '../../data/models/pending_employee_match.dart';
import '../../../attendance/data/models/employee_model.dart';

/// A device user id seen in the punch log with nobody mapped to it.
typedef UnmappedUser = ({
  String deviceUserId,
  int punchCount,
  DateTime lastSeen,
});

class DeviceState {
  final DeviceSettingsModel settings;

  /// What the terminal said about itself on the last successful test.
  final ZkConnectionInfo? connection;

  /// People enrolled on the terminal, loaded on demand for the mapping list.
  final List<ZkDeviceUserModel> deviceUsers;

  final List<EmployeeModel> employees;
  final List<UnmappedUser> unmapped;

  /// Terminal users the import held back because somebody already on file
  /// answers to the same name. Nothing has been written for these yet.
  final List<PendingEmployeeMatch> pendingMatches;

  /// The device user id currently being resolved, so only its own row shows a
  /// spinner while the rest of the review stays usable.
  final String? resolvingMatchFor;

  final DateTime? lastSync;
  final DeviceSyncResult? lastResult;

  final bool isTesting;
  final bool isSyncing;
  final bool isLoadingUsers;

  /// The wipe or reboot currently running on the terminal, so only its own row
  /// shows a spinner while the rest of the maintenance card stays readable.
  final ZkResetAction? resettingAction;

  /// A session is held open and punches are arriving as they happen.
  final bool isLive;

  /// When the most recent live punch landed, for the device screen to show.
  final DateTime? lastLivePunchAt;

  /// Localization keys, never raw text — the UI translates them.
  final String? error;
  final String? message;

  const DeviceState({
    this.settings = const DeviceSettingsModel(),
    this.connection,
    this.deviceUsers = const [],
    this.employees = const [],
    this.unmapped = const [],
    this.pendingMatches = const [],
    this.resolvingMatchFor,
    this.lastSync,
    this.lastResult,
    this.isTesting = false,
    this.isSyncing = false,
    this.isLoadingUsers = false,
    this.resettingAction,
    this.isLive = false,
    this.lastLivePunchAt,
    this.error,
    this.message,
  });

  bool get isBusy =>
      isTesting || isSyncing || isLoadingUsers || isResetting;

  /// A reset holds the terminal's only session, so nothing else may start.
  bool get isResetting => resettingAction != null;

  bool get hasPendingMatches => pendingMatches.isNotEmpty;

  /// Employees with no terminal id yet — the other half of the mapping problem.
  List<EmployeeModel> get unmappedEmployees =>
      employees.where((e) => (e.deviceUserId ?? '').isEmpty).toList();

  /// A name for a device user id, when the terminal has told us one.
  String? nameForDeviceUser(String deviceUserId) {
    for (final user in deviceUsers) {
      if (user.deviceUserId == deviceUserId && user.name.isNotEmpty) {
        return user.name;
      }
    }
    return null;
  }

  DeviceState copyWith({
    DeviceSettingsModel? settings,
    ZkConnectionInfo? connection,
    List<ZkDeviceUserModel>? deviceUsers,
    List<EmployeeModel>? employees,
    List<UnmappedUser>? unmapped,
    List<PendingEmployeeMatch>? pendingMatches,
    String? resolvingMatchFor,
    DateTime? lastSync,
    DeviceSyncResult? lastResult,
    bool? isTesting,
    bool? isSyncing,
    bool? isLoadingUsers,
    ZkResetAction? resettingAction,
    bool? isLive,
    DateTime? lastLivePunchAt,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
    bool clearConnection = false,
    bool clearResolvingMatch = false,
    bool clearResettingAction = false,
  }) => DeviceState(
    settings: settings ?? this.settings,
    connection: clearConnection ? null : (connection ?? this.connection),
    deviceUsers: deviceUsers ?? this.deviceUsers,
    employees: employees ?? this.employees,
    unmapped: unmapped ?? this.unmapped,
    pendingMatches: pendingMatches ?? this.pendingMatches,
    resolvingMatchFor: clearResolvingMatch
        ? null
        : (resolvingMatchFor ?? this.resolvingMatchFor),
    lastSync: lastSync ?? this.lastSync,
    lastResult: lastResult ?? this.lastResult,
    isTesting: isTesting ?? this.isTesting,
    isSyncing: isSyncing ?? this.isSyncing,
    isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
    resettingAction: clearResettingAction
        ? null
        : (resettingAction ?? this.resettingAction),
    isLive: isLive ?? this.isLive,
    lastLivePunchAt: lastLivePunchAt ?? this.lastLivePunchAt,
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
  );
}
