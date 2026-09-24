import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_id.dart';

/// The single SQLite connection the whole app shares.
///
/// sqflite has no Windows implementation, so the desktop build goes through
/// sqflite_common_ffi against the SQLite library bundled with the executable.
/// [init] must run once, before the service locator builds anything that
/// touches the database.
class AppDatabase {
  static const _fileName = 'guardsync.db';

  /// 4 — added app_sequences, so a staff number is never reissued after the
  ///     employee holding it is deleted.
  /// 5 — added attendance_records.breaks, so a day can hold every break the
  ///     person took rather than only the first departure and last return.
  /// 6 — added attendance_records.corrected_at / corrected_by, the receipt for
  ///     the admin's single same-day correction of a day's punches.
  /// 7 — added pending_employee_matches, so a terminal user who looks like
  ///     somebody already on file waits for an admin instead of becoming a
  ///     second copy of them.
  /// 8 — added departments, so the admin picks an employee's department from a
  ///     list they maintain rather than retyping it into a free-text box.
  /// 9 — added shifts and employees.shift_id, so a company that runs more than
  ///     one working day judges each person against their own hours instead of
  ///     one company-wide pair of times.
  /// 10 — added holidays and shifts.rest_days, so the app knows which dates
  ///     nobody was expected to work rather than treating every date on the
  ///     calendar as a working day.
  static const _schemaVersion = 10;

  Database? _db;

  /// Where [init] opened the file. Kept so a restore can put the connection
  /// back exactly where it was, having closed it to replace the file underneath.
  String? _file;

  /// The open connection. Throws if [init] has not completed, which can only
  /// happen through a wiring mistake, never at runtime.
  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('AppDatabase.init() must be awaited before use.');
    }
    return database;
  }

  /// Where the database file lives, for the backup/export screen to show.
  String get path => db.path;

  /// [overridePath] replaces the default location — pass
  /// [inMemoryDatabasePath] in tests so no file is touched and path_provider
  /// (which needs a Flutter binding) is never called.
  Future<void> init({String? overridePath}) async {
    if (_db != null) return;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final String file;
    if (overridePath != null) {
      file = overridePath;
    } else if (_file != null) {
      // Reopening after a restore closed the connection. The location was
      // settled the first time; resolving it again would only risk landing
      // somewhere else.
      file = _file!;
    } else {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      file = p.join(directory.path, _fileName);
    }
    _file = file;

    _db = await databaseFactory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async {
          // Off by default in SQLite; without it the employee cascade below
          // silently leaves orphaned attendance rows behind.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async => _createSchema(db),
        onUpgrade: (db, from, to) async => _upgrade(db, from, to),
      ),
    );
  }

  /// Copies the live database to [destinationPath]. Used by the backup action —
  /// with no server, the file on this PC is the only copy of the data.
  Future<File> backupTo(String destinationPath) async {
    // Flushes the write-ahead log into the main file so the copy is complete.
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    return File(db.path).copy(destinationPath);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Replaces the live database with a backup taken earlier, and reopens.
  ///
  /// The file is checked before anything is touched, and the database it is
  /// about to replace is copied aside first. Both matter more here than they
  /// look: this is a single-PC install, so the file being overwritten holds
  /// every attendance record made since that backup, and there is no server to
  /// fetch them back from. A restore that turns out to be the wrong file has to
  /// be survivable.
  ///
  /// A backup from an older schema is accepted — reopening runs the same
  /// migrations an upgrade would. One from a *newer* build is refused, since
  /// there is no migration backwards.
  ///
  /// Every data source reads the connection through [db] on each call rather
  /// than holding one, so they all pick up the reopened database with no
  /// rewiring.
  Future<void> restoreFrom(String sourcePath) async {
    final target = _file ?? db.path;
    await _verifyRestorable(sourcePath);

    // Flushed before the copy aside, or the rollback would be missing whatever
    // is still sitting in the write-ahead log.
    await db.execute('PRAGMA wal_checkpoint(FULL)');
    await close();

    final rollback = '$target.pre-restore';
    try {
      if (await File(target).exists()) await File(target).copy(rollback);
      await File(sourcePath).copy(target);

      // The sidecars belong to the database that was just replaced. Left in
      // place, SQLite would replay them over the restored file and corrupt it.
      await _removeSidecars(target);
    } catch (e) {
      try {
        if (await File(rollback).exists()) await File(rollback).copy(target);
        await _removeSidecars(target);
      } catch (_) {
        // Nothing further to try. The reopen below still runs: an app left
        // with no connection at all is worse than one on a damaged file, and
        // the rollback copy is still on disk to be recovered by hand.
      }
      await init();
      throw DatabaseRestoreException(
        RestoreRefusal.unreadable,
        detail: e.toString(),
      );
    }

    await init();
  }

  /// Refuses a file that is not a database this build can open, before the
  /// live one has been touched.
  Future<void> _verifyRestorable(String sourcePath) async {
    if (!await File(sourcePath).exists()) {
      throw const DatabaseRestoreException(RestoreRefusal.unreadable);
    }

    Database? probe;
    try {
      // Read-only, and outside the factory's instance cache: opening it as a
      // second live handle on the same path is exactly what must not happen.
      probe = await databaseFactory.openDatabase(
        sourcePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );

      // Read by hand rather than through `firstIntValue`, which the ffi
      // package does not re-export.
      final versionRows = await probe.rawQuery('PRAGMA user_version');
      final version = versionRows.isEmpty
          ? 0
          : (versionRows.first.values.first as int? ?? 0);
      if (version > _schemaVersion) {
        throw DatabaseRestoreException(
          RestoreRefusal.tooNew,
          detail: 'v$version',
        );
      }

      final tables = {
        for (final row in await probe.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          row['name'] as String,
      };
      final missing = _requiredTables.difference(tables);
      if (missing.isNotEmpty) {
        throw DatabaseRestoreException(
          RestoreRefusal.incomplete,
          detail: missing.join(', '),
        );
      }
    } on DatabaseRestoreException {
      rethrow;
    } catch (e) {
      throw DatabaseRestoreException(
        RestoreRefusal.notADatabase,
        detail: e.toString(),
      );
    } finally {
      try {
        await probe?.close();
      } catch (_) {}
    }
  }

  /// Enough of the schema to tell one of our backups from any other SQLite
  /// file an admin might pick by mistake.
  static const _requiredTables = {
    'users',
    'employees',
    'attendance_records',
  };

  static Future<void> _removeSidecars(String target) async {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$target$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  /// Existing installs already hold real attendance, so schema changes are
  /// applied in place rather than by recreating the database.
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      // The terminal reports six punch modes; v1 only had room for two.
      const columns = [
        'break_out_time',
        'break_in_time',
        'overtime_in_time',
        'overtime_out_time',
      ];
      for (final column in columns) {
        await db.execute(
          'ALTER TABLE attendance_records ADD COLUMN $column TEXT',
        );
      }
    }

    if (from < 3) {
      await db.execute(_dismissedTable);
    }

    if (from < 4) {
      await db.execute(_sequenceTable);
      // Start above whatever is already in use so an existing install does not
      // hand out a number twice.
      await _seedEmployeeSequence(db);
    }

    if (from < 5) {
      // Every break of the day, as JSON. The two single columns stay as the
      // summary they always were — first departure, last return — so nothing
      // reading them has to change.
      await db.execute('ALTER TABLE attendance_records ADD COLUMN breaks TEXT');
    }

    if (from < 6) {
      // When an admin corrected the day, and who. Its presence is both the
      // receipt — the correction is spent — and the lock: the device fold
      // skips a day that carries it.
      await db.execute(
        'ALTER TABLE attendance_records ADD COLUMN corrected_at TEXT',
      );
      await db.execute(
        'ALTER TABLE attendance_records ADD COLUMN corrected_by TEXT',
      );
    }

    if (from < 7) {
      await db.execute(_pendingMatchTable);
    }

    if (from < 8) {
      await db.execute(_departmentTable);
      await db.execute(_departmentNameIndex);
      // An existing install already has departments — typed by hand, one
      // employee at a time. They become the first entries in the list, or the
      // admin would open a picker with nothing in it and their staff filed
      // under names it does not offer.
      await _seedDepartments(db);
    }

    if (from < 9) {
      await db.execute(_shiftTable);
      await db.execute(_shiftNameIndex);
      // Nobody is put on a shift by the upgrade. A null shift means "the
      // company default", which is exactly the single set of hours every
      // existing employee is already judged by — so an install that never
      // opens the shifts screen behaves precisely as it did before.
      await db.execute('ALTER TABLE employees ADD COLUMN shift_id TEXT');
      await db.execute(_employeeShiftIndex);
    }

    if (from < 10) {
      await db.execute(_holidayTable);
      await db.execute(_holidayRangeIndex);
      // No rest days for anybody by default: an install that never opens the
      // calendar keeps treating every date as a working day, exactly as it did
      // before this column existed.
      await db.execute(
        "ALTER TABLE shifts ADD COLUMN rest_days TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  /// Dates nobody in the company was expected to work.
  ///
  /// A range rather than a single date, because the holidays that matter here
  /// come in runs — Eid is several days, and a company shutdown can be a week.
  /// Entering one row per day would be tedious enough that somebody would skip
  /// it, and a calendar with gaps is worse than none.
  ///
  /// Company-wide on purpose. A rest day is a property of the schedule
  /// somebody works and belongs on the shift; a public holiday is a property
  /// of the date and applies to everybody, whichever shift they are on.
  static const _holidayTable = '''
    CREATE TABLE IF NOT EXISTS holidays (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date   TEXT NOT NULL,
      is_paid    INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )
  ''';

  /// Every screen that judges a month asks which of its dates are holidays, so
  /// the range is looked up far more often than it is written.
  static const _holidayRangeIndex = '''
    CREATE INDEX IF NOT EXISTS ix_holidays_range
      ON holidays (start_date, end_date)
  ''';

  /// The working days the admin defines, one per set of hours the company runs.
  ///
  /// Deliberately not a foreign key on `employees`, for the same reason
  /// `departments` is not: SQLite cannot add a constrained column to a table
  /// that already has rows without rebuilding it, and rebuilding the employee
  /// table on an install holding real attendance is not worth the constraint.
  /// [ShiftsLocalDataSource] does the work the constraint would have done —
  /// deleting a shift releases the people on it in the same transaction, and a
  /// `shift_id` pointing at nothing falls back to the company default rather
  /// than failing.
  ///
  /// The two allowances are minutes, not times: the admin is saying how much
  /// lateness and how early a departure the shift forgives, and a clock time
  /// would only repeat the start and end already in the row.
  static const _shiftTable = '''
    CREATE TABLE IF NOT EXISTS shifts (
      id                      TEXT PRIMARY KEY,
      name                    TEXT NOT NULL,
      start_work              TEXT NOT NULL,
      end_work                TEXT NOT NULL,
      late_grace_minutes      INTEGER NOT NULL DEFAULT 0,
      early_out_grace_minutes INTEGER NOT NULL DEFAULT 0,
      -- The weekdays this shift does not work, as DateTime.weekday numbers:
      -- '5,6' is Friday and Saturday. Empty means it works every day, which
      -- is what every shift created before the calendar existed does.
      rest_days               TEXT NOT NULL DEFAULT '',
      created_at              TEXT NOT NULL
    )
  ''';

  /// Two shifts with one name would be indistinguishable in the employee
  /// picker, which is the only place a shift is ever chosen.
  static const _shiftNameIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS ix_shifts_name
      ON shifts (name COLLATE NOCASE)
  ''';

  /// Every report counts the people on a shift, and the fold looks one up per
  /// employee-day.
  static const _employeeShiftIndex = '''
    CREATE INDEX IF NOT EXISTS ix_employees_shift ON employees (shift_id)
  ''';

  /// The departments an employee can be filed under.
  ///
  /// Deliberately not a foreign key on `employees`. The department is stored on
  /// the employee as its name, and every report, export and filter in the app
  /// reads it that way; turning it into an id would have rewritten all of them
  /// for no gain. This table is the catalogue the picker offers, and
  /// [DepartmentsLocalDataSource] unions it with the names actually in use so a
  /// department can never vanish from under the people standing in it.
  static const _departmentTable = '''
    CREATE TABLE IF NOT EXISTS departments (
      id         TEXT PRIMARY KEY,
      name       TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  /// Two spellings of one department would split its staff in every report, so
  /// the name is the key whatever case it is typed in.
  static const _departmentNameIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS ix_departments_name
      ON departments (name COLLATE NOCASE)
  ''';

  /// Fills the catalogue from the departments employees are already in.
  static Future<void> _seedDepartments(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT DISTINCT TRIM(department) AS name FROM employees "
      "WHERE TRIM(department) <> ''",
    );

    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      await db.insert(
        'departments',
        {
          'id': DbId.generate(),
          'name': row['name'] as String,
          'created_at': now,
        },
        // Two employees in the same department is the normal case, and the
        // index folds case on top of that.
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Monotonic counters. A staff number derived from `MAX(employee_number)`
  /// would be reissued as soon as its holder was deleted, silently pointing an
  /// old payroll reference at a different person.
  static const _sequenceTable = '''
    CREATE TABLE IF NOT EXISTS app_sequences (
      name  TEXT PRIMARY KEY,
      value INTEGER NOT NULL
    )
  ''';

  static Future<void> _seedEmployeeSequence(DatabaseExecutor db) async {
    final rows = await db.query(
      'employees',
      columns: ['employee_number'],
      where: 'employee_number IS NOT NULL',
    );

    var highest = 0;
    for (final row in rows) {
      final match = RegExp(
        r'(\d+)$',
      ).firstMatch(row['employee_number'] as String? ?? '');
      final value = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (value > highest) highest = value;
    }

    await db.insert('app_sequences', {
      'name': 'employee_number',
      'value': highest,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Device user ids an admin has deleted.
  ///
  /// Without this, deleting an employee is undone by the next sync: the person
  /// is still enrolled on the terminal, so the employee import recreates them.
  static const _dismissedTable = '''
    CREATE TABLE IF NOT EXISTS dismissed_device_users (
      device_user_id TEXT PRIMARY KEY,
      dismissed_at   TEXT NOT NULL,
      removed_from_device INTEGER NOT NULL DEFAULT 0
    )
  ''';

  /// Terminal users the import would not create on its own, because somebody
  /// already on file answers to the same name.
  ///
  /// The import stops there and writes the question down rather than guessing.
  /// Guessing wrong is not a duplicate row — it files one person's attendance
  /// under another, and nothing later in the pipeline can tell that happened.
  /// The row records only that the question exists, and how the terminal spells
  /// the name. Who it might be is worked out again each time the review is
  /// opened, so an employee deleted or linked by hand in the meantime cannot be
  /// offered as an answer.
  static const _pendingMatchTable = '''
    CREATE TABLE IF NOT EXISTS pending_employee_matches (
      device_user_id TEXT PRIMARY KEY,
      device_name    TEXT NOT NULL DEFAULT '',
      detected_at    TEXT NOT NULL
    )
  ''';

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    // Local accounts. Replaces the JWT users table — a password hash and a role
    // are all a single-PC deployment needs.
    batch.execute('''
      CREATE TABLE users (
        id            TEXT PRIMARY KEY,
        email         TEXT NOT NULL COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        display_name  TEXT NOT NULL DEFAULT '',
        role          TEXT NOT NULL DEFAULT 'guard',
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE UNIQUE INDEX ix_users_email ON users (email)');

    batch.execute('''
      CREATE TABLE employees (
        id                     TEXT PRIMARY KEY,
        employee_number        TEXT,
        full_name              TEXT NOT NULL,
        department             TEXT NOT NULL DEFAULT '',
        photo_url              TEXT,
        has_housing            INTEGER NOT NULL DEFAULT 0,
        has_travel_permission  INTEGER NOT NULL DEFAULT 0,
        phone                  TEXT,
        position               TEXT,
        qr_code                TEXT,
        device_user_id         TEXT,
        -- The working day this person is judged by. Null means the company
        -- default from the work-hours settings, which is what a site running
        -- one shift never has to change.
        shift_id               TEXT,
        is_active              INTEGER NOT NULL DEFAULT 1,
        created_at             TEXT NOT NULL,
        updated_at             TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE UNIQUE INDEX ix_employees_number ON employees (employee_number)
        WHERE employee_number IS NOT NULL
    ''');
    // The link back to the terminal. Unique so two employees can never claim
    // the same fingerprint enrolment.
    batch.execute('''
      CREATE UNIQUE INDEX ix_employees_device_user ON employees (device_user_id)
        WHERE device_user_id IS NOT NULL
    ''');
    batch.execute('CREATE INDEX ix_employees_active ON employees (is_active)');

    batch.execute('''
      CREATE TABLE attendance_records (
        id              TEXT PRIMARY KEY,
        employee_id     TEXT NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
        date            TEXT NOT NULL,
        check_in_time   TEXT,
        check_out_time  TEXT,
        break_out_time  TEXT,
        break_in_time   TEXT,
        -- Every break of the day as a JSON array of {"out","in"} pairs; the two
        -- columns above are the first departure and the last return.
        breaks          TEXT,
        overtime_in_time  TEXT,
        overtime_out_time TEXT,
        status          TEXT NOT NULL DEFAULT 'pending',
        notes           TEXT,
        guard_name      TEXT,
        is_early_leave  INTEGER NOT NULL DEFAULT 0,
        source          TEXT NOT NULL DEFAULT 'manual',
        -- The admin's one same-day correction: when it was made and by whom.
        -- Null until it is used, and the device fold leaves the day alone once
        -- it is set.
        corrected_at    TEXT,
        corrected_by    TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');
    // One record per employee per day — the constraint that makes the device
    // sync idempotent instead of duplicating a row on every poll.
    batch.execute('''
      CREATE UNIQUE INDEX ix_attendance_employee_date
        ON attendance_records (employee_id, date)
    ''');
    batch.execute(
      'CREATE INDEX ix_attendance_date ON attendance_records (date)',
    );

    batch.execute('''
      CREATE TABLE permission_requests (
        id               TEXT PRIMARY KEY,
        employee_id      TEXT NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
        permission_type  TEXT NOT NULL,
        date             TEXT NOT NULL,
        start_time       TEXT,
        end_time         TEXT,
        reason           TEXT,
        status           TEXT NOT NULL DEFAULT 'approved',
        approved_by      TEXT,
        notes            TEXT,
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE INDEX ix_permissions_employee_date_type
        ON permission_requests (employee_id, date, permission_type)
    ''');
    batch.execute(
      'CREATE INDEX ix_permissions_date ON permission_requests (date)',
    );

    batch.execute('''
      CREATE TABLE admin_notifications (
        id                TEXT PRIMARY KEY,
        type              TEXT NOT NULL,
        employee_id       TEXT NOT NULL,
        employee_name     TEXT NOT NULL DEFAULT '',
        message           TEXT NOT NULL DEFAULT '',
        date              TEXT NOT NULL,
        early_leave_count INTEGER NOT NULL DEFAULT 0,
        is_read           INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX ix_notifications_read ON admin_notifications (is_read)',
    );
    batch.execute('''
      CREATE INDEX ix_notifications_employee_type_date
        ON admin_notifications (employee_id, type, date)
    ''');

    // Raw punches exactly as the terminal reported them. Kept verbatim so a
    // re-sync is idempotent and so a mis-mapped employee can be re-folded later
    // without another trip to the device.
    batch.execute('''
      CREATE TABLE device_punches (
        id              TEXT PRIMARY KEY,
        device_user_id  TEXT NOT NULL,
        punch_time      TEXT NOT NULL,
        state           INTEGER,
        type            INTEGER,
        employee_id     TEXT,
        synced_at       TEXT NOT NULL
      )
    ''');
    // The dedupe key. getAttendanceLogs() returns the device's whole buffer on
    // every call, so the same punch arrives again on each sync.
    batch.execute('''
      CREATE UNIQUE INDEX ix_punch_unique
        ON device_punches (device_user_id, punch_time)
    ''');
    batch.execute('CREATE INDEX ix_punch_time ON device_punches (punch_time)');
    batch.execute(
      'CREATE INDEX ix_punch_employee ON device_punches (employee_id)',
    );

    batch.execute(_dismissedTable);
    batch.execute(_sequenceTable);
    batch.execute(_pendingMatchTable);
    batch.execute(_departmentTable);
    batch.execute(_departmentNameIndex);
    batch.execute(_shiftTable);
    batch.execute(_shiftNameIndex);
    batch.execute(_employeeShiftIndex);
    batch.execute(_holidayTable);
    batch.execute(_holidayRangeIndex);

    await batch.commit(noResult: true);
  }
}

/// Why [AppDatabase.restoreFrom] would not take a file.
///
/// Kept as a reason rather than a message: this is the database layer, which
/// has no business knowing the language. The backup data source turns each of
/// these into a localization key.
enum RestoreRefusal {
  /// The path is gone, or the copy over the live file failed.
  unreadable,

  /// Not SQLite, or too damaged to open.
  notADatabase,

  /// Written by a newer build of the app. Migrations only run forwards.
  tooNew,

  /// A database, but not one of ours — the core tables are missing.
  incomplete,
}

class DatabaseRestoreException implements Exception {
  final RestoreRefusal reason;
  final String? detail;

  const DatabaseRestoreException(this.reason, {this.detail});

  @override
  String toString() => 'DatabaseRestoreException($reason, detail: $detail)';
}
