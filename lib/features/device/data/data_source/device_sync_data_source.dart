import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/name_matching.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../shifts/data/models/shift_model.dart';
import '../models/device_settings_model.dart';
import '../models/pending_employee_match.dart';
import 'punch_type_resolver.dart';

/// Turns raw terminal punches into the one-row-per-employee-per-day shape the
/// rest of the app reads.
///
/// Nobody selects a punch mode on the terminal keypad: the six columns are
/// worked out here from the times themselves by [PunchTypeResolver], so a
/// person only ever has to put a finger on the sensor. The mode the device
/// reports is still stored with the raw punch, but nothing reads it.
class DeviceSyncDataSource {
  static const _punches = 'device_punches';
  static const _attendance = 'attendance_records';
  static const _employees = 'employees';
  static const _pendingMatches = 'pending_employee_matches';

  final AppDatabase _database;

  /// Reads the admin's working hours. A function rather than the settings data
  /// source itself: the fold only needs the current values, and this keeps the
  /// dependency to one call that a test can stand in for.
  final WorkSchedule Function()? _readSchedule;

  DeviceSyncDataSource(this._database, [this._readSchedule]);

  Database get _db => _database.db;

  WorkSchedule get _schedule => _readSchedule?.call() ?? kDefaultSchedule;

  /// Creates an employee for every enrolled terminal user that is plainly new,
  /// and writes the rest down as a question for an admin.
  ///
  /// Names come off the device in Windows-1256 and are already decoded by the
  /// parser. An employee that already carries this device id is left alone —
  /// an admin's edits outrank whatever is typed on the terminal keypad.
  ///
  /// The device id is the only identity the terminal and this database really
  /// share, and somebody entered by hand has none: their `device_user_id` is
  /// null until a link is made. Matching on that id alone therefore read every
  /// hand-entered employee as a stranger and created a second copy of them the
  /// first time they put a finger on the sensor. So a terminal user whose
  /// *name* answers to somebody already on file is neither created here nor
  /// linked here — it is parked in [_pendingMatches] for [getPendingMatches]
  /// to put in front of an admin.
  ///
  /// Neither half of that is a judgement this code can make: two people do
  /// share a name, and linking the wrong one does not leave a duplicate row
  /// anybody would spot — it files one person's attendance under another,
  /// silently. Their punches keep arriving and sit unmapped in the punch log
  /// while the question waits, so nothing is lost by waiting: answering it
  /// replays the whole history through [refoldUnmapped].
  Future<({int created, int pending, List<ZkDeviceUserModel> dismissed})>
  importEmployees(List<ZkDeviceUserModel> users) async {
    return _guard(() async {
      final known = await _deviceUserMapping();
      final dismissed = await _dismissedDeviceUsers();

      // Questions that have since answered themselves — somebody linked or
      // deleted the person by hand while the review sat there.
      await _prunePendingMatches(known.keys.toSet(), dismissed);

      if (users.isEmpty) {
        return (created: 0, pending: 0, dismissed: const <ZkDeviceUserModel>[]);
      }

      final unlinked = await _unlinkedEmployees();
      final now = DateTime.now().toIso8601String();
      var created = 0;
      var pending = 0;

      // Deliberately deleted before, and still enrolled on the terminal. They
      // are refused here as they always were, but the caller is told who they
      // were: a fetch that silently returns nothing because every id on the
      // device carries an old tombstone is indistinguishable from a broken
      // cable, and there is otherwise no way back from it.
      final refused = <ZkDeviceUserModel>[];

      // Imported people need a staff number like anyone else, taken from the
      // same counter the form uses so the two routes never collide.
      var sequence = await _peekEmployeeSequence();

      for (final user in users) {
        if (known.containsKey(user.deviceUserId)) continue;
        // Deleted by an admin. The terminal may still hold the enrolment — if
        // the device was unreachable at the time — and without this the next
        // sync would quietly undo the deletion.
        if (dismissed.contains(user.deviceUserId)) {
          refused.add(user);
          continue;
        }

        if (_candidatesFor(user.name, unlinked).isNotEmpty) {
          await _db.insert(
            _pendingMatches,
            {
              'device_user_id': user.deviceUserId,
              'device_name': user.name,
              'detected_at': now,
            },
            // Already asked on an earlier sync. Ignoring the repeat keeps the
            // original detected_at, so a question the admin has been sitting on
            // does not look new again at every poll.
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          pending++;
          continue;
        }

        await _createEmployee(
          deviceUserId: user.deviceUserId,
          name: user.name,
          sequence: ++sequence,
          now: now,
        );
        created++;
      }

      if (created > 0) await _saveEmployeeSequence(sequence);
      return (created: created, pending: pending, dismissed: refused);
    });
  }

  /// Everyone an admin has deleted, newest first.
  ///
  /// The tombstone is what stops a deletion undoing itself at the next sync, so
  /// it has to outlive the employee. But it is not meant to be a life sentence:
  /// somebody who left and came back is enrolled on the same terminal under the
  /// same id, and without a way to read this list back there is nothing to
  /// clear and no way to get them in again.
  Future<List<({String deviceUserId, bool removedFromDevice, DateTime at})>>
  getDismissedDeviceUsers() async {
    return _guard(() async {
      final rows = await _db.query(
        'dismissed_device_users',
        orderBy: 'dismissed_at DESC',
      );
      return [
        for (final row in rows)
          (
            deviceUserId: row['device_user_id'] as String? ?? '',
            removedFromDevice: (row['removed_from_device'] as int? ?? 0) != 0,
            at:
                DateTime.tryParse(row['dismissed_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
      ].where((r) => r.deviceUserId.isNotEmpty).toList();
    });
  }

  /// Lifts the deletion on several people at once, so the next fetch brings
  /// them back in.
  Future<int> restoreDeviceUsers(List<String> deviceUserIds) async {
    return _guard(() async {
      final ids = deviceUserIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return 0;

      return _db.delete(
        'dismissed_device_users',
        where: 'device_user_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    });
  }

  /// The unresolved questions, each carrying everyone it could be.
  ///
  /// The candidates are worked out afresh rather than read back from the row,
  /// so somebody deleted or linked since the sync is never offered as an
  /// answer. Needs no connection to the terminal — the name it reported is
  /// kept on the row, so the review works with the device unplugged.
  Future<List<PendingEmployeeMatch>> getPendingMatches() async {
    return _guard(() async {
      final rows = await _db.query(_pendingMatches, orderBy: 'detected_at ASC');
      if (rows.isEmpty) return const <PendingEmployeeMatch>[];

      final known = await _deviceUserMapping();
      final unlinked = await _unlinkedEmployees();
      final matches = <PendingEmployeeMatch>[];

      for (final row in rows) {
        final deviceUserId = row['device_user_id'] as String? ?? '';
        if (deviceUserId.isEmpty) continue;

        final deviceName = row['device_name'] as String? ?? '';
        final candidates = _candidatesFor(deviceName, unlinked);

        // Nobody left to confuse them with, or the link was made elsewhere.
        // The question is moot: drop it and let the next sync treat them like
        // any other new enrolment.
        if (candidates.isEmpty || known.containsKey(deviceUserId)) {
          await _db.delete(
            _pendingMatches,
            where: 'device_user_id = ?',
            whereArgs: [deviceUserId],
          );
          continue;
        }

        matches.add(
          PendingEmployeeMatch(
            deviceUserId: deviceUserId,
            deviceName: deviceName,
            candidates: candidates,
            detectedAt:
                DateTime.tryParse(row['detected_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
      return matches;
    });
  }

  /// The admin's answer: the same person.
  ///
  /// Links the terminal id onto the employee already on file instead of
  /// creating a second one — the whole point of the review. Their own details
  /// are left untouched; the keypad has nothing to say about a name an admin
  /// typed.
  Future<void> confirmPendingMatch({
    required String deviceUserId,
    required String employeeId,
  }) async {
    return _guard(() async {
      // Re-checked here, not only when the list was built: the review may have
      // sat on screen while another route linked or deleted this employee.
      final rows = await _db.query(
        _employees,
        columns: ['device_user_id'],
        where: 'id = ?',
        whereArgs: [employeeId],
        limit: 1,
      );
      if (rows.isEmpty) throw ApiException(LangKeys.errorEmployeeNotFound);

      final current = rows.first['device_user_id'] as String? ?? '';
      if (current.isNotEmpty && current != deviceUserId) {
        throw ApiException(LangKeys.errorDuplicateDeviceUser);
      }

      final taken = await _db.query(
        _employees,
        columns: ['id'],
        where: 'device_user_id = ? AND id != ?',
        whereArgs: [deviceUserId, employeeId],
        limit: 1,
      );
      if (taken.isNotEmpty) {
        throw ApiException(LangKeys.errorDuplicateDeviceUser);
      }

      await _db.update(
        _employees,
        {
          'device_user_id': deviceUserId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [employeeId],
      );

      await _db.delete(
        _pendingMatches,
        where: 'device_user_id = ?',
        whereArgs: [deviceUserId],
      );
    });
  }

  /// The admin's other answer: a different person who happens to share a name.
  ///
  /// Creates them exactly as the import would have, had nobody stood in the
  /// way.
  Future<void> rejectPendingMatch(String deviceUserId) async {
    return _guard(() async {
      final rows = await _db.query(
        _pendingMatches,
        columns: ['device_name'],
        where: 'device_user_id = ?',
        whereArgs: [deviceUserId],
        limit: 1,
      );

      final sequence = await _peekEmployeeSequence() + 1;
      await _createEmployee(
        deviceUserId: deviceUserId,
        name: rows.isEmpty ? '' : (rows.first['device_name'] as String? ?? ''),
        sequence: sequence,
        now: DateTime.now().toIso8601String(),
      );
      await _saveEmployeeSequence(sequence);

      await _db.delete(
        _pendingMatches,
        where: 'device_user_id = ?',
        whereArgs: [deviceUserId],
      );
    });
  }

  /// How many questions are waiting, for a badge that does not need the list.
  Future<int> pendingMatchCount() async {
    return _guard(() async {
      final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_pendingMatches',
      );
      return (rows.first['c'] as int?) ?? 0;
    });
  }

  /// Stores [punches] and rebuilds every attendance day they touch.
  Future<DeviceSyncResult> ingest(
    List<ZkPunchModel> punches, {
    int debounceSeconds = 60,
    int employeesImported = 0,
  }) async {
    return _guard(() async {
      if (punches.isEmpty) {
        return DeviceSyncResult(employeesImported: employeesImported);
      }

      final mapping = await _deviceUserMapping();
      final unmapped = <String>{};
      var inserted = 0;

      final touched = <({String employeeId, String date})>{};

      await _db.transaction((txn) async {
        for (final punch in punches) {
          final employeeId = mapping[punch.deviceUserId];
          if (employeeId == null) unmapped.add(punch.deviceUserId);

          // The unique index on (device_user_id, punch_time) makes the re-read
          // of the device's whole buffer idempotent.
          final rows = await txn.insert(_punches, {
            'id': DbId.generate(),
            'device_user_id': punch.deviceUserId,
            'punch_time': punch.timestamp.toIso8601String(),
            'state': punch.state,
            'type': punch.type,
            'employee_id': employeeId,
            'synced_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          if (rows != 0) {
            inserted++;
            if (employeeId != null) {
              touched.add((
                employeeId: employeeId,
                date: _dateOf(punch.timestamp),
              ));
            }
          }
        }
      });

      var written = 0;
      for (final day in touched) {
        final changed = await _foldDay(
          employeeId: day.employeeId,
          date: day.date,
          debounceSeconds: debounceSeconds,
        );
        if (changed) written++;
      }

      return DeviceSyncResult(
        punchesRead: punches.length,
        punchesNew: inserted,
        recordsWritten: written,
        unmappedUserIds: unmapped,
        employeesImported: employeesImported,
      );
    });
  }

  /// Re-runs the fold for punches that arrived before their employee was
  /// mapped. Called after an admin links a device user to an employee, so
  /// history is picked up rather than lost.
  Future<int> refoldUnmapped({int debounceSeconds = 60}) async {
    return _guard(() async {
      final mapping = await _deviceUserMapping();
      if (mapping.isEmpty) return 0;

      final orphans = await _db.query(
        _punches,
        columns: ['device_user_id', 'punch_time'],
        where:
            'employee_id IS NULL AND device_user_id IN '
            '(${List.filled(mapping.length, '?').join(',')})',
        whereArgs: mapping.keys.toList(),
      );
      if (orphans.isEmpty) return 0;

      final touched = <({String employeeId, String date})>{};

      await _db.transaction((txn) async {
        for (final row in orphans) {
          final deviceUserId = row['device_user_id'] as String;
          final employeeId = mapping[deviceUserId];
          if (employeeId == null) continue;

          await txn.update(
            _punches,
            {'employee_id': employeeId},
            where: 'device_user_id = ? AND punch_time = ?',
            whereArgs: [deviceUserId, row['punch_time']],
          );

          final time = DateTime.tryParse(row['punch_time'] as String? ?? '');
          if (time != null) {
            touched.add((employeeId: employeeId, date: _dateOf(time)));
          }
        }
      });

      var written = 0;
      for (final day in touched) {
        final changed = await _foldDay(
          employeeId: day.employeeId,
          date: day.date,
          debounceSeconds: debounceSeconds,
        );
        if (changed) written++;
      }
      return written;
    });
  }

  /// Rebuilds every attendance day between [startDate] and [endDate] from the
  /// punches already stored, and returns how many rows changed.
  ///
  /// The punch log is the raw record and is never rewritten, so re-reading it
  /// is how days folded under older rules — or under the terminal's own mode
  /// keys — pick up the current ones. The report's refresh runs this over the
  /// range on screen.
  Future<int> refoldRange(
    String startDate,
    String endDate, {
    int debounceSeconds = 60,
  }) async {
    return _guard(() async {
      final rows = await _db.rawQuery(
        '''
        SELECT DISTINCT employee_id,
               substr(punch_time, 1, 10) AS day
        FROM $_punches
        WHERE employee_id IS NOT NULL
          AND substr(punch_time, 1, 10) BETWEEN ? AND ?
      ''',
        [startDate, endDate],
      );

      var written = 0;
      for (final row in rows) {
        final changed = await _foldDay(
          employeeId: row['employee_id'] as String,
          date: row['day'] as String,
          debounceSeconds: debounceSeconds,
        );
        if (changed) written++;
      }
      return written;
    });
  }

  /// Device user ids seen in the punch log with no employee mapped to them,
  /// newest first — the worklist for the mapping screen.
  Future<List<({String deviceUserId, int punchCount, DateTime lastSeen})>>
  getUnmappedUserIds() async {
    return _guard(() async {
      final rows = await _db.rawQuery('''
        SELECT device_user_id,
               COUNT(*)          AS punch_count,
               MAX(punch_time)   AS last_seen
        FROM $_punches
        WHERE employee_id IS NULL
        GROUP BY device_user_id
        ORDER BY last_seen DESC
      ''');

      return rows
          .map(
            (r) => (
              deviceUserId: r['device_user_id'] as String? ?? '',
              punchCount: (r['punch_count'] as int?) ?? 0,
              lastSeen:
                  DateTime.tryParse(r['last_seen'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .where((r) => r.deviceUserId.isNotEmpty)
          .toList();
    });
  }

  Future<DateTime?> lastSyncTime() async {
    return _guard(() async {
      final rows = await _db.rawQuery(
        'SELECT MAX(synced_at) AS t FROM $_punches',
      );
      return DateTime.tryParse(rows.first['t'] as String? ?? '');
    });
  }

  // --------------------------------------------------------------- the fold

  /// Rebuilds one employee's record for one day from their stored punches.
  ///
  /// Returns whether anything changed, so a sync that re-reads the same buffer
  /// reports zero writes instead of inflating its own numbers.
  Future<bool> _foldDay({
    required String employeeId,
    required String date,
    required int debounceSeconds,
  }) async {
    final rows = await _db.query(
      _punches,
      columns: ['punch_time'],
      where: 'employee_id = ? AND punch_time LIKE ?',
      whereArgs: [employeeId, '$date%'],
      orderBy: 'punch_time ASC',
    );
    if (rows.isEmpty) return false;

    final punches = <DateTime>[];
    for (final row in rows) {
      final at = DateTime.tryParse(row['punch_time'] as String? ?? '');
      if (at != null) punches.add(at);
    }
    if (punches.isEmpty) return false;

    final employee = await _employee(employeeId);
    if (employee == null) return false;

    // This person's shift, or the company default when they are on none. Two
    // people scanning the same minute can land on different sides of "late"
    // because they work different days, and that is the whole point of it.
    final schedule = employee.schedule;

    // Each person's day ends at their own hour, and that hour is what tells a
    // break apart from a departure and a departure apart from overtime.
    final day = PunchTypeResolver.resolve(
      PunchTypeResolver.debounce(punches, Duration(seconds: debounceSeconds)),
      dayEndMinutes: expectedWorkEndMinutes(
        DateTime.parse(date),
        hasHousing: employee.hasHousing,
        hasTravelPermission: employee.hasTravelPermission,
        schedule: schedule,
      ),
    );

    final existing = await _db.query(
      _attendance,
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      limit: 1,
    );

    // A day an admin has corrected is final. The punches themselves stay in
    // the log — they are the raw record and are never rewritten — but the row
    // they fold into is left exactly as the admin left it. Without this the
    // next sync would quietly undo the one correction they were allowed.
    if (existing.isNotEmpty && existing.first['corrected_at'] != null) {
      return false;
    }

    // A placeholder absence, written because the day had no punches at the
    // time it was closed. These punches are the evidence it was waiting for,
    // so the row stops being one: it is refilled and handed back to the
    // device, or a day that later turned out to be worked would keep reading
    // as system-written and could be cleared by a reopen.
    final wasClosedEmpty =
        existing.isNotEmpty && existing.first['source'] == 'system';

    // A row somebody typed is widened rather than overwritten: the earliest
    // arrival and the latest departure win, so a hand-entered time is never
    // silently dropped. A row the device wrote itself has no such claim on it —
    // re-folding it has to be able to move a time, or a day worked out under
    // older rules would keep its old answer forever.
    final wasTypedByHand =
        existing.isNotEmpty &&
        !wasClosedEmpty &&
        existing.first['source'] != 'device';
    final currentIn = wasTypedByHand
        ? existing.first['check_in_time'] as String?
        : null;
    final currentOut = wasTypedByHand
        ? existing.first['check_out_time'] as String?
        : null;

    final checkIn = _earlier(currentIn, day.checkIn);
    final checkOut = _later(currentOut, day.checkOut);

    final status = computeDayStatus(
      day: DateTime.parse(date),
      checkIn: checkIn,
      checkOut: checkOut,
      hasHousing: employee.hasHousing,
      hasTravelPermission: employee.hasTravelPermission,
      schedule: schedule,
    );

    final isEarlyLeave =
        checkOut != null &&
        isEarlyCheckoutOn(
          DateTime.parse(date),
          checkOut,
          hasHousing: employee.hasHousing,
          hasTravelPermission: employee.hasTravelPermission,
          schedule: schedule,
        );

    final values = <String, Object?>{
      'check_in_time': checkIn,
      'check_out_time': checkOut,
      'break_out_time': day.firstBreakOut,
      'break_in_time': day.lastBreakIn,
      'breaks': AttendanceBreak.encode(day.breaks),
      'overtime_in_time': day.overtimeIn,
      'overtime_out_time': day.overtimeOut,
      'status': status,
      'is_early_leave': isEarlyLeave ? 1 : 0,
      if (wasClosedEmpty) 'source': 'device',
    };

    final now = DateTime.now().toIso8601String();

    if (existing.isEmpty) {
      await _db.insert(_attendance, {
        'id': DbId.generate(),
        'employee_id': employeeId,
        'date': date,
        ...values,
        'notes': null,
        'guard_name': null,
        'source': 'device',
        'created_at': now,
        'updated_at': now,
      });
      return true;
    }

    final row = existing.first;
    final unchanged = values.entries.every((e) => row[e.key] == e.value);
    if (unchanged) return false;

    // notes and guard_name are left alone — they are a human's work and the
    // device has nothing to say about them.
    await _db.update(
      _attendance,
      {
        ...values,
        'source': row['source'] == 'manual' ? 'merged' : 'device',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    return true;
  }

  /// Records that an admin deleted this device user, so [importEmployees]
  /// leaves them alone from now on.
  ///
  /// [removedFromDevice] false means the terminal still holds the enrolment —
  /// the delete could not reach it — which the device screen surfaces so an
  /// admin can clear the fingerprint by hand.
  Future<void> dismissDeviceUser(
    String deviceUserId, {
    required bool removedFromDevice,
  }) async {
    return _guard(() async {
      final id = deviceUserId.trim();
      if (id.isEmpty) return;

      await _db.insert('dismissed_device_users', {
        'device_user_id': id,
        'dismissed_at': DateTime.now().toIso8601String(),
        'removed_from_device': removedFromDevice ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Their punches are no longer anybody's, but they stay on record so the
      // history is not silently rewritten.
      await _db.update(
        _punches,
        {'employee_id': null},
        where: 'device_user_id = ?',
        whereArgs: [id],
      );

      // Any question about who they were is settled by the deletion itself.
      await _db.delete(
        _pendingMatches,
        where: 'device_user_id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Undoes a dismissal, letting the next sync import that person again.
  Future<void> restoreDeviceUser(String deviceUserId) async {
    return _guard(() async {
      await _db.delete(
        'dismissed_device_users',
        where: 'device_user_id = ?',
        whereArgs: [deviceUserId.trim()],
      );
    });
  }

  /// Deleted device users the terminal has *not* confirmed removing, so the
  /// admin can be told their fingerprint is still enrolled.
  Future<List<String>> getStrandedDeviceUsers() async {
    return _guard(() async {
      final rows = await _db.query(
        'dismissed_device_users',
        columns: ['device_user_id'],
        where: 'removed_from_device = 0',
      );
      return rows
          .map((r) => r['device_user_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    });
  }

  /// Reads the shared staff-number counter.
  ///
  /// The same counter the manual form draws from, so a number issued by one
  /// route is never handed out again by the other.
  Future<int> _peekEmployeeSequence() async {
    final rows = await _db.query(
      'app_sequences',
      columns: ['value'],
      where: 'name = ?',
      whereArgs: ['employee_number'],
      limit: 1,
    );
    if (rows.isNotEmpty) return (rows.first['value'] as int?) ?? 0;

    final employees = await _db.query(
      _employees,
      columns: ['employee_number'],
      where: 'employee_number IS NOT NULL',
    );
    var highest = 0;
    for (final row in employees) {
      final match = RegExp(
        r'(\d+)$',
      ).firstMatch(row['employee_number'] as String? ?? '');
      final value = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (value > highest) highest = value;
    }
    return highest;
  }

  Future<void> _saveEmployeeSequence(int value) => _db.insert('app_sequences', {
    'name': 'employee_number',
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Everyone carrying no terminal id yet — the pool a device user's name is
  /// tried against.
  ///
  /// Deactivated people are in the pool deliberately: somebody returning after
  /// a long absence is precisely the case that would otherwise come back as a
  /// second person with an empty attendance history.
  Future<List<_UnlinkedEmployee>> _unlinkedEmployees() async {
    final rows = await _db.query(
      _employees,
      columns: ['id', 'full_name', 'employee_number', 'department'],
      where: "device_user_id IS NULL OR device_user_id = ''",
    );
    return [
      for (final row in rows)
        (
          employeeId: row['id'] as String,
          fullName: row['full_name'] as String? ?? '',
          employeeNumber: row['employee_number'] as String?,
          department: row['department'] as String? ?? '',
        ),
    ];
  }

  /// Everyone in [pool] whose name could be the person the terminal calls
  /// [deviceName], surest reading first.
  ///
  /// An empty device name matches nobody: a blank keypad entry is not evidence
  /// about anyone, and treating it as one would hold up every unnamed enrolment
  /// behind a review it can never pass.
  static List<EmployeeMatchCandidate> _candidatesFor(
    String deviceName,
    List<_UnlinkedEmployee> pool,
  ) {
    if (deviceName.trim().isEmpty) return const [];

    final matches = <EmployeeMatchCandidate>[];
    for (final employee in pool) {
      final confidence = NameMatching.compare(deviceName, employee.fullName);
      if (confidence == null) continue;
      matches.add((
        employeeId: employee.employeeId,
        fullName: employee.fullName,
        employeeNumber: employee.employeeNumber,
        department: employee.department,
        confidence: confidence,
      ));
    }

    matches.sort((a, b) => a.confidence.index.compareTo(b.confidence.index));
    return matches;
  }

  /// Drops questions that no longer have an answer to give: the person was
  /// linked by hand, or deleted outright, while the review waited.
  Future<void> _prunePendingMatches(
    Set<String> linked,
    Set<String> dismissed,
  ) async {
    final resolved = {...linked, ...dismissed};
    if (resolved.isEmpty) return;

    await _db.delete(
      _pendingMatches,
      where:
          'device_user_id IN (${List.filled(resolved.length, '?').join(',')})',
      whereArgs: resolved.toList(),
    );
  }

  /// The one place an employee is born from a terminal enrolment, so the import
  /// and the admin's "different person" answer cannot drift apart.
  Future<void> _createEmployee({
    required String deviceUserId,
    required String name,
    required int sequence,
    required String now,
  }) {
    final trimmed = name.trim();
    return _db.insert(_employees, {
      'id': DbId.generate(),
      'employee_number': 'EMP${sequence.toString().padLeft(3, '0')}',
      'full_name': trimmed.isEmpty ? 'Device #$deviceUserId' : trimmed,
      'department': '',
      'device_user_id': deviceUserId,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Set<String>> _dismissedDeviceUsers() async {
    final rows = await _db.query(
      'dismissed_device_users',
      columns: ['device_user_id'],
    );
    return rows
        .map((r) => r['device_user_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Map<String, String>> _deviceUserMapping() async {
    final rows = await _db.query(
      _employees,
      columns: ['id', 'device_user_id'],
      where: 'device_user_id IS NOT NULL',
    );
    return {
      for (final row in rows)
        (row['device_user_id'] as String): (row['id'] as String),
    };
  }

  /// The employee's allowances and the working hours their day is judged by.
  ///
  /// The shift is joined in rather than looked up separately: the fold runs
  /// this once per employee-day and a second round trip per day would be paid
  /// for on every sync. A null `shift_id`, or one left pointing at a deleted
  /// shift, resolves to the company default — see [ShiftModel.scheduleFromRow].
  Future<({bool hasHousing, bool hasTravelPermission, WorkSchedule schedule})?>
  _employee(String id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT e.has_housing, e.has_travel_permission,
             s.start_work, s.end_work,
             s.late_grace_minutes, s.early_out_grace_minutes, s.rest_days
        FROM $_employees e
        LEFT JOIN shifts s ON s.id = e.shift_id
       WHERE e.id = ?
       LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;

    return (
      hasHousing: (rows.first['has_housing'] as int? ?? 0) != 0,
      hasTravelPermission:
          (rows.first['has_travel_permission'] as int? ?? 0) != 0,
      schedule: ShiftModel.scheduleFromRow(rows.first, _schedule),
    );
  }

  static String _dateOf(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  static String? _earlier(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return timeToMinutes(a) <= timeToMinutes(b) ? a : b;
  }

  static String? _later(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return timeToMinutes(a) >= timeToMinutes(b) ? a : b;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DatabaseException catch (e) {
      throw ApiException(LangKeys.errorDatabase, detail: e.toString());
    } catch (e) {
      throw ApiException(LangKeys.errorUnknown, detail: e.toString());
    }
  }
}

/// An employee not yet tied to a terminal id, as the matcher needs them.
typedef _UnlinkedEmployee = ({
  String employeeId,
  String fullName,
  String? employeeNumber,
  String department,
});
