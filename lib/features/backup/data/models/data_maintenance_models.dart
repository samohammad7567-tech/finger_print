/// What the database is actually holding, for the cleanup screen to show
/// before it offers to remove any of it.
///
/// An admin deciding whether to clear a year of history needs to see the size
/// of the thing first — "clear old data" with no numbers beside it is a button
/// nobody can judge.
class DataFootprint {
  final int employees;
  final int attendanceDays;
  final int punches;
  final int permissions;
  final int notifications;

  /// Size of the database file on disk.
  final int databaseBytes;

  /// The earliest attendance date on file, or null when there is none. Seeds
  /// the date picker so the admin is not made to guess where history starts.
  final String? oldestAttendanceDate;

  const DataFootprint({
    this.employees = 0,
    this.attendanceDays = 0,
    this.punches = 0,
    this.permissions = 0,
    this.notifications = 0,
    this.databaseBytes = 0,
    this.oldestAttendanceDate,
  });

  bool get isEmpty =>
      employees == 0 && attendanceDays == 0 && punches == 0;

  /// Megabytes, one decimal — the only unit worth showing for a file this
  /// size, and the one an admin can compare against their disk.
  String get databaseSizeMb => (databaseBytes / (1024 * 1024)).toStringAsFixed(1);
}

/// What a clear-before-date actually removed.
class PurgeResult {
  final int attendanceRemoved;
  final int punchesRemoved;
  final int permissionsRemoved;
  final int notificationsRemoved;

  /// How much smaller the file got. Reported because reclaiming space is
  /// usually the whole reason the button was pressed.
  final int bytesFreed;

  const PurgeResult({
    this.attendanceRemoved = 0,
    this.punchesRemoved = 0,
    this.permissionsRemoved = 0,
    this.notificationsRemoved = 0,
    this.bytesFreed = 0,
  });

  int get total =>
      attendanceRemoved +
      punchesRemoved +
      permissionsRemoved +
      notificationsRemoved;

  bool get removedNothing => total == 0;

  String get freedMb => (bytesFreed / (1024 * 1024)).toStringAsFixed(1);
}
