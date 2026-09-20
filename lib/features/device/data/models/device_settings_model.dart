/// How to reach the ZKTeco terminal, and how to interpret what it returns.
class DeviceSettingsModel {
  /// The terminal's address on the local network.
  final String ip;

  /// 4370 on every ZKTeco standalone terminal unless it has been changed in
  /// the device's own Comm menu.
  final int port;

  /// The device's "comm key". Empty on a factory-default terminal; when set,
  /// the device rejects the session until the key is presented.
  final String commKey;

  /// Newer firmware speaks TCP; older units only answer on UDP.
  final bool useTcp;

  /// Many office networks block ICMP while leaving 4370 open, which makes the
  /// library's pre-flight ping fail on a device that is perfectly reachable.
  /// Turning this on skips that check.
  final bool skipPing;

  /// Minutes between automatic syncs. Zero disables the timer, leaving only
  /// the manual "sync now" action.
  final int autoSyncMinutes;

  /// Two scans by the same person inside this window count as one punch.
  /// Guards against the double-read a fingerprint reader commonly produces.
  final int debounceSeconds;

  /// Create an employee for every person enrolled on the terminal that the app
  /// does not already know. Off means the admin adds employees by hand and
  /// maps them to a device id themselves.
  final bool importEmployees;

  /// Hold a session open so a punch reaches the app the moment the terminal
  /// accepts a finger, instead of waiting for the next poll.
  ///
  /// The device allows one session at a time, so this one is stood down
  /// automatically whenever another operation needs the terminal.
  final bool liveSync;

  const DeviceSettingsModel({
    this.ip = '',
    this.port = 4370,
    this.commKey = '',
    this.useTcp = true,
    this.skipPing = false,
    this.autoSyncMinutes = 10,
    this.debounceSeconds = 60,
    this.importEmployees = true,
    this.liveSync = true,
  });

  bool get isConfigured => ip.trim().isNotEmpty;

  DeviceSettingsModel copyWith({
    String? ip,
    int? port,
    String? commKey,
    bool? useTcp,
    bool? skipPing,
    int? autoSyncMinutes,
    int? debounceSeconds,
    bool? importEmployees,
    bool? liveSync,
  }) => DeviceSettingsModel(
    ip: ip ?? this.ip,
    port: port ?? this.port,
    commKey: commKey ?? this.commKey,
    useTcp: useTcp ?? this.useTcp,
    skipPing: skipPing ?? this.skipPing,
    autoSyncMinutes: autoSyncMinutes ?? this.autoSyncMinutes,
    debounceSeconds: debounceSeconds ?? this.debounceSeconds,
    importEmployees: importEmployees ?? this.importEmployees,
    liveSync: liveSync ?? this.liveSync,
  );
}

/// The six things a scan can mean, and the attendance column each one fills.
///
/// A ZKTeco terminal can record these as modes the operator picks on the keypad
/// before scanning, but this app does not ask anyone to: the sync works the
/// mode out from the time of the scan instead. The [code] is kept because it is
/// what the device reports, and the raw punch row still stores it.
enum ZkPunchType {
  checkIn(0, 'check_in'),
  checkOut(1, 'check_out'),
  breakOut(2, 'break_out'),
  breakIn(3, 'break_in'),
  overtimeIn(4, 'overtime_in'),
  overtimeOut(5, 'overtime_out');

  const ZkPunchType(this.code, this.column);

  /// The value the device reports.
  final int code;

  /// The attendance_records column this punch fills.
  final String column;

  static ZkPunchType? fromCode(int? code) {
    if (code == null) return null;
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// A single scan as the terminal reported it.
class ZkPunchModel {
  /// The user id as enrolled on the device — the value that maps to an
  /// employee's `deviceUserId`.
  final String deviceUserId;

  final DateTime timestamp;

  /// Verification method (fingerprint, card, password). Stored but not yet
  /// interpreted.
  final int? state;

  /// The punch mode the terminal recorded, as a raw code. See [ZkPunchType].
  /// Stored with the punch for the record, but nothing reads it — what a scan
  /// means is decided from its time, not from a key somebody pressed.
  final int? type;

  const ZkPunchModel({
    required this.deviceUserId,
    required this.timestamp,
    this.state,
    this.type,
  });

  ZkPunchType? get punchType => ZkPunchType.fromCode(type);
}

/// A person enrolled on the terminal, for the mapping screen.
class ZkDeviceUserModel {
  final String deviceUserId;
  final String name;
  final int? uid;

  const ZkDeviceUserModel({
    required this.deviceUserId,
    required this.name,
    this.uid,
  });
}

/// What a completed sync did, for the UI to report.
class DeviceSyncResult {
  /// Punches the terminal returned in total.
  final int punchesRead;

  /// Punches not already in the local table.
  final int punchesNew;

  /// Attendance rows created or amended from those punches.
  final int recordsWritten;

  /// Device user ids with punches but no employee mapped to them. These are
  /// kept, not dropped — mapping the employee later re-folds them.
  final Set<String> unmappedUserIds;

  /// Employees created from the terminal's own enrolment list this run.
  final int employeesImported;

  /// Terminal users the import held back because somebody already on file
  /// answers to the same name. Nothing was written for these — an admin says
  /// whether they are the same person before anything is linked or created.
  final int employeesPendingReview;

  const DeviceSyncResult({
    this.punchesRead = 0,
    this.punchesNew = 0,
    this.recordsWritten = 0,
    this.unmappedUserIds = const {},
    this.employeesImported = 0,
    this.employeesPendingReview = 0,
  });
}
