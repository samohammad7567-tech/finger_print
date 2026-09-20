import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_id.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/name_matching.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../../shifts/data/models/shift_model.dart';
import '../models/attendance_record_model.dart';
import '../models/employee_import_models.dart';
import '../models/employee_model.dart';

/// Employees and attendance records in the local SQLite database.
///
/// Method-for-method identical to the remote data source it replaces, so the
/// repo, the cubits and every screen above them are untouched by the move off
/// the API. Failures still surface as [ApiException] carrying a localization
/// key, which keeps the single error path the UI already understands.
class AttendanceLocalDataSource {
  static const _employees = 'employees';
  static const _attendance = 'attendance_records';

  /// Prefix for generated staff numbers.
  static const _numberPrefix = 'EMP';
  static const _employeeSequence = 'employee_number';

  final AppDatabase _database;

  /// Reads the admin's working hours. A function rather than the settings data
  /// source itself: a correction only needs the current values to work out
  /// what the day now reads as, and this keeps the dependency to one call a
  /// test can stand in for.
  final WorkSchedule Function()? _readSchedule;

  AttendanceLocalDataSource(this._database, [this._readSchedule]);

  Database get _db => _database.db;

  // ------------------------------------------------------------- employees

  Future<List<EmployeeModel>> getEmployees() => _employeeList(activeOnly: true);

  Future<List<EmployeeModel>> getAllEmployees() =>
      _employeeList(activeOnly: false);

  Future<EmployeeModel?> getEmployeeById(String id) async {
    return _guard(() async {
      final rows = await _db.query(
        _employees,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      // A missing employee is a normal result for a deep link, not an error.
      return rows.isEmpty ? null : EmployeeModel.fromJson(rows.first);
    });
  }

  /// The staff number the next new employee will receive.
  ///
  /// Read-only preview for the form — [_reserveEmployeeNumber] is what actually
  /// consumes one.
  Future<String> nextEmployeeNumber() async {
    return _guard(() async => _format(await _peekSequence() + 1));
  }

  /// Takes the next number out of the sequence.
  ///
  /// The counter is what keeps two routes — the form and the device import —
  /// from handing out the same number inside one run. It is not a promise that
  /// a number is never reused: [resequenceEmployeeNumbers] closes the gap a
  /// deletion leaves and resets the counter to match, because the admin asked
  /// for a list that always reads 001..N with nothing missing.
  ///
  /// The cost of that, stated once here: a number identifies a row in this list
  /// and nothing else. Attendance, punches and notifications all key off the
  /// internal id, so renumbering breaks no link inside the app — but a payroll
  /// reference or an exported report kept outside it will, after a deletion,
  /// name a different person.
  Future<String> _reserveEmployeeNumber() async {
    var value = await _peekSequence();
    var candidate = _format(++value);
    var guard = 0;

    while (await _employeeNumberTaken(candidate, null) && guard < 10000) {
      candidate = _format(++value);
      guard++;
    }

    await _db.insert('app_sequences', {
      'name': _employeeSequence,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return candidate;
  }

  Future<int> _peekSequence() async {
    final rows = await _db.query(
      'app_sequences',
      columns: ['value'],
      where: 'name = ?',
      whereArgs: [_employeeSequence],
      limit: 1,
    );
    if (rows.isNotEmpty) return (rows.first['value'] as int?) ?? 0;

    // First use on a database that predates the counter.
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

  static String _format(int value) =>
      '$_numberPrefix${value.toString().padLeft(3, '0')}';

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) async {
    return _guard(() async {
      // Blank means "give me the next one" — the form pre-fills it, and the
      // device import leaves it empty.
      final number =
          _normalize(data['employee_id']) ?? await _reserveEmployeeNumber();
      // A reserved number is already known to be free; this catches one an
      // admin typed over the top of it.
      if (await _employeeNumberTaken(number, null)) {
        throw const ApiException(LangKeys.errorDuplicateEmployeeNumber);
      }

      final deviceUserId = _normalize(data['device_user_id']);
      if (deviceUserId != null &&
          await _deviceUserIdTaken(deviceUserId, null)) {
        throw const ApiException(LangKeys.errorDuplicateDeviceUser);
      }

      final now = _nowIso();
      final id = DbId.generate();

      await _db.insert(_employees, {
        'id': id,
        'employee_number': number,
        'full_name': (data['full_name'] as String? ?? '').trim(),
        'department': (data['department'] as String? ?? '').trim(),
        'photo_url': _normalize(data['photo_url']),
        'has_housing': _int(data['has_housing']),
        'has_travel_permission': _int(data['has_travel_permission']),
        'phone': _normalize(data['phone']),
        'position': _normalize(data['position']),
        'qr_code': _normalize(data['qr_code']),
        'device_user_id': deviceUserId,
        'shift_id': _normalize(data['shift_id']),
        'is_active': _int(data['is_active'], fallback: 1),
        'created_at': now,
        'updated_at': now,
      });

      final created = await getEmployeeById(id);
      if (created == null) throw const ApiException(LangKeys.errorUnknown);
      return created;
    });
  }

  /// Creates everybody in [rows] that is not already on file.
  ///
  /// Deliberately not one transaction: a spreadsheet somebody maintains by
  /// hand always has a bad line in it, and rolling back ninety good employees
  /// because row 14 has no name would make the feature useless. Each row
  /// stands or falls on its own and the refusals are reported back.
  ///
  /// A row is skipped, never merged, when it names somebody the app already
  /// knows — importing the same sheet twice must not double the workforce.
  Future<EmployeeImportResult> importEmployees(
    List<EmployeeImportRow> rows,
  ) async {
    return _guard(() async {
      final onFile = {
        for (final employee in await getAllEmployees())
          NameMatching.key(employee.fullName),
      }..remove('');
      final seenInFile = <String>{};

      final created = <EmployeeModel>[];
      final skipped = <EmployeeImportIssue>[];

      void skip(EmployeeImportRow row, String reasonKey) => skipped.add(
        EmployeeImportIssue(
          line: row.line,
          name: row.fullName,
          reasonKey: reasonKey,
        ),
      );

      for (final row in rows) {
        if (!row.hasName) {
          skip(row, LangKeys.importRowNoName);
          continue;
        }
        if (onFile.contains(row.nameKey)) {
          skip(row, LangKeys.importRowDuplicateName);
          continue;
        }
        // Tracked separately from [onFile] so the second copy of somebody the
        // file itself lists twice is told the truth about which it is.
        if (!seenInFile.add(row.nameKey)) {
          skip(row, LangKeys.importRowRepeatedInFile);
          continue;
        }

        final number = row.employeeNumber;
        if (number != null && await _employeeNumberTaken(number, null)) {
          skip(row, LangKeys.errorDuplicateEmployeeNumber);
          continue;
        }

        final deviceUserId = row.deviceUserId;
        if (deviceUserId != null &&
            await _deviceUserIdTaken(deviceUserId, null)) {
          skip(row, LangKeys.errorDuplicateDeviceUser);
          continue;
        }

        try {
          created.add(await createEmployee(row.toEmployeeData()));
        } on ApiException catch (e) {
          // createEmployee has already reduced the failure to a key, so the
          // row can say what went wrong rather than just "failed".
          skip(row, e.errorKey);
        } catch (_) {
          skip(row, LangKeys.importRowFailed);
        }
      }

      return EmployeeImportResult(created: created, skipped: skipped);
    });
  }

  Future<EmployeeModel> updateEmployee(
    String id,
    Map<String, dynamic> data,
  ) async {
    return _guard(() async {
      final existing = await getEmployeeById(id);
      if (existing == null) throw const ApiException(LangKeys.errorNotFound);

      final updates = <String, Object?>{};

      // A key that is absent means "leave unchanged", matching how the screens
      // post sparse maps such as { "is_active": false }.
      if (data.containsKey('employee_id')) {
        final number = _normalize(data['employee_id']);
        if (number != null && await _employeeNumberTaken(number, id)) {
          throw const ApiException(LangKeys.errorDuplicateEmployeeNumber);
        }
        updates['employee_number'] = number;
      }

      if (data.containsKey('device_user_id')) {
        final deviceUserId = _normalize(data['device_user_id']);
        if (deviceUserId != null &&
            await _deviceUserIdTaken(deviceUserId, id)) {
          throw const ApiException(LangKeys.errorDuplicateDeviceUser);
        }
        updates['device_user_id'] = deviceUserId;
      }

      if (data.containsKey('full_name')) {
        updates['full_name'] = (data['full_name'] as String? ?? '').trim();
      }
      if (data.containsKey('department')) {
        updates['department'] = (data['department'] as String? ?? '').trim();
      }
      if (data.containsKey('photo_url')) {
        updates['photo_url'] = _normalize(data['photo_url']);
      }
      if (data.containsKey('has_housing')) {
        updates['has_housing'] = _int(data['has_housing']);
      }
      if (data.containsKey('has_travel_permission')) {
        updates['has_travel_permission'] = _int(data['has_travel_permission']);
      }
      if (data.containsKey('phone')) {
        updates['phone'] = _normalize(data['phone']);
      }
      if (data.containsKey('position')) {
        updates['position'] = _normalize(data['position']);
      }
      if (data.containsKey('qr_code')) {
        updates['qr_code'] = _normalize(data['qr_code']);
      }
      // Null is a real answer here, not a missing one: it puts this employee
      // back on the company's default hours.
      if (data.containsKey('shift_id')) {
        updates['shift_id'] = _normalize(data['shift_id']);
      }
      if (data.containsKey('is_active')) {
        updates['is_active'] = _int(data['is_active'], fallback: 1);
      }

      updates['updated_at'] = _nowIso();

      await _db.update(_employees, updates, where: 'id = ?', whereArgs: [id]);

      final updated = await getEmployeeById(id);
      if (updated == null) throw const ApiException(LangKeys.errorNotFound);
      return updated;
    });
  }

  Future<void> deleteEmployee(String id) async {
    return _guard(() async {
      // Attendance and permissions cascade by the foreign key, matching the
      // previous behaviour of removing the employee outright.
      final removed = await _db.delete(
        _employees,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (removed == 0) throw const ApiException(LangKeys.errorNotFound);

      // The gap the deletion just opened is closed straight away, so the list
      // never shows a hole an admin has to wonder about.
      await resequenceEmployeeNumbers();
    });
  }

  /// Rewrites every staff number so the list reads EMP001..EMP00N with nothing
  /// missing, and points the counter at the end of it.
  ///
  /// Order is the order people were added, so a renumber only ever moves those
  /// standing *after* whoever was removed — everybody before them keeps the
  /// number they already had. Sorting by anything else (name, say) would let a
  /// single new hire renumber the entire staff at once.
  ///
  /// Done in two passes inside one transaction because `ix_employees_number` is
  /// unique: assigning EMP002 to the person currently holding EMP003 collides
  /// with the EMP002 that has not been rewritten yet. Clearing the column first
  /// is safe — the index is partial (`WHERE employee_number IS NOT NULL`) — and
  /// the transaction means a failure half way leaves every number as it was
  /// rather than a list of blanks.
  ///
  /// Returns how many numbers actually changed, so a caller can stay quiet when
  /// the answer is none.
  Future<int> resequenceEmployeeNumbers() async {
    return _guard(() async {
      var changed = 0;

      await _db.transaction((txn) async {
        final rows = await txn.query(
          _employees,
          columns: ['id', 'employee_number'],
          orderBy: 'created_at ASC, rowid ASC',
        );

        final wanted = <String, String>{};
        for (final (index, row) in rows.indexed) {
          final id = row['id'] as String;
          final number = _format(index + 1);
          if (row['employee_number'] != number) {
            wanted[id] = number;
            changed++;
          }
        }

        if (wanted.isNotEmpty) {
          for (final id in wanted.keys) {
            await txn.update(
              _employees,
              {'employee_number': null},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
          for (final entry in wanted.entries) {
            await txn.update(
              _employees,
              {'employee_number': entry.value, 'updated_at': _nowIso()},
              where: 'id = ?',
              whereArgs: [entry.key],
            );
          }
        }

        // Reset even when not one number moved. Deleting the last employee
        // changes nobody else's number but still frees the one they held, and a
        // counter left pointing past the end of the list would skip it — the
        // list would read 001, 002, 004 after the very next hire.
        await txn.insert('app_sequences', {
          'name': _employeeSequence,
          'value': rows.length,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

      return changed;
    });
  }

  /// Employees who answer to the same name, grouped.
  ///
  /// Worked out from the list itself rather than stored, so it is never stale:
  /// renaming one of them makes the clash disappear without anything having to
  /// be cleared. Comparison goes through [NameMatching] for the same reason the
  /// device import does — "أبو خالد" and "ابو خالد" are one name written twice.
  ///
  /// A clash is not an error. Two people really can share a name, and when they
  /// do the admin needs to see both, know which of them the terminal recognises,
  /// and be able to write a name that tells them apart.
  Future<List<EmployeeNameClash>> findNameClashes() async {
    return _guard(() async {
      final employees = await getAllEmployees();

      final byName = <String, List<EmployeeModel>>{};
      for (final employee in employees) {
        final key = NameMatching.key(employee.fullName);
        // Somebody with no name at all is a data problem, not a clash.
        if (key.isEmpty) continue;
        byName.putIfAbsent(key, () => []).add(employee);
      }

      final clashes = [
        for (final entry in byName.entries)
          if (entry.value.length > 1)
            EmployeeNameClash(nameKey: entry.key, employees: entry.value),
      ];

      // The ones the admin is most likely to have just created come first.
      clashes.sort((a, b) => b.employees.length.compareTo(a.employees.length));
      return clashes;
    });
  }

  // ------------------------------------------------------------ attendance

  Future<List<AttendanceRecordModel>> getRecordsByDate(String date) =>
      _recordList(where: 'r.date = ?', args: [date]);

  Future<List<AttendanceRecordModel>> getRecordsByEmployee(String employeeId) =>
      _recordList(where: 'r.employee_id = ?', args: [employeeId]);

  Future<List<AttendanceRecordModel>> getRecordsByDateRange(
    String startDate,
    String endDate,
  ) => _recordList(
    where: 'r.date >= ? AND r.date <= ?',
    args: [startDate, endDate],
  );

  Future<List<AttendanceRecordModel>> getRecentRecords(int limit) =>
      _recordList(limit: limit);

  Future<AttendanceRecordModel?> findRecord(
    String employeeId,
    String date,
  ) async {
    return _guard(() async {
      final rows = await _recordList(
        where: 'r.employee_id = ? AND r.date = ?',
        args: [employeeId, date],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    });
  }

  Future<AttendanceRecordModel> createRecord(
    AttendanceRecordModel record,
  ) async {
    return _guard(() async {
      if (!await _employeeExists(record.employeeId)) {
        throw const ApiException(LangKeys.errorEmployeeNotFound);
      }

      // The unique index is the real guard; this turns the common case into a
      // clear duplicate key instead of a raw SQLite error.
      final existing = await findRecord(record.employeeId, record.date);
      if (existing != null) {
        throw const ApiException(LangKeys.errorDuplicateRecord);
      }

      final now = _nowIso();
      final id = DbId.generate();

      await _db.insert(_attendance, {
        'id': id,
        'employee_id': record.employeeId,
        'date': record.date,
        'check_in_time': record.checkInTime,
        'check_out_time': record.checkOutTime,
        'status': record.status,
        'notes': record.notes,
        'guard_name': record.guardName,
        'is_early_leave': record.isEarlyLeave ? 1 : 0,
        'source': 'manual',
        'created_at': now,
        'updated_at': now,
      });

      final created = await _recordById(id);
      if (created == null) throw const ApiException(LangKeys.errorUnknown);
      return created;
    });
  }

  /// The admin's one correction of a day's punches.
  ///
  /// Only the day it happened, and only once. Both halves are checked here
  /// rather than trusted from the screen: a disabled button is a courtesy, and
  /// this is the rule. The status and the early-leave flag are worked out
  /// again from the corrected times, so the report cannot be left saying
  /// something the times no longer support.
  ///
  /// Passing null for a time clears it — a scan that never happened is not the
  /// same as one at 00:00 — but a correction that empties both is refused,
  /// since it would spend the day's one chance on nothing.
  Future<AttendanceRecordModel> correctPunches({
    required String recordId,
    String? checkInTime,
    String? checkOutTime,
    String? correctedBy,
  }) async {
    return _guard(() async {
      final record = await _recordById(recordId);
      if (record == null) {
        throw const ApiException(LangKeys.errorRecordNotFound);
      }
      if (record.isCorrected) {
        throw const ApiException(LangKeys.errorCorrectionUsed);
      }
      if (!record.canCorrectOn(DateTime.now())) {
        throw const ApiException(LangKeys.errorCorrectionNotToday);
      }

      final checkIn = _correctedTime(checkInTime);
      final checkOut = _correctedTime(checkOutTime);
      if (checkIn == null && checkOut == null) {
        throw const ApiException(LangKeys.errorCorrectionEmpty);
      }
      if (checkIn != null &&
          checkOut != null &&
          timeToMinutes(checkOut) <= timeToMinutes(checkIn)) {
        throw const ApiException(LangKeys.errorCorrectionOrder);
      }

      final employee = await getEmployeeById(record.employeeId);
      // This person's own working day, not the company's. A correction has to
      // land on the same rules the fold would have used, or an admin fixing a
      // mistyped punch would silently re-judge the day by somebody else's
      // hours.
      final schedule = await _scheduleFor(record.employeeId);
      final day = DateTime.tryParse(record.date) ?? DateTime.now();
      final hasHousing = employee?.hasHousing ?? false;
      final hasTravel = employee?.hasTravelPermission ?? false;

      final now = _nowIso();

      await _db.update(
        _attendance,
        {
          'check_in_time': checkIn,
          'check_out_time': checkOut,
          'status': computeDayStatus(
            day: day,
            checkIn: checkIn,
            checkOut: checkOut,
            hasHousing: hasHousing,
            hasTravelPermission: hasTravel,
            schedule: schedule,
          ),
          'is_early_leave':
              checkOut != null &&
                  isEarlyCheckoutOn(
                    day,
                    checkOut,
                    hasHousing: hasHousing,
                    hasTravelPermission: hasTravel,
                    schedule: schedule,
                  )
              ? 1
              : 0,
          'source': 'corrected',
          'corrected_at': now,
          'corrected_by': _normalize(correctedBy),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );

      final saved = await _recordById(recordId);
      if (saved == null) throw const ApiException(LangKeys.errorUnknown);
      return saved;
    });
  }

  /// A corrected time as 'HH:mm', or null when the field was left empty.
  /// Anything that is neither is the admin's typo, not a time.
  static String? _correctedTime(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw const ApiException(LangKeys.errorCorrectionTime);
    }
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  Future<AttendanceRecordModel> updateRecord(
    String id,
    Map<String, dynamic> updates,
  ) async {
    return _guard(() async {
      final columns = <String, Object?>{};

      if (updates.containsKey('check_in_time')) {
        columns['check_in_time'] = updates['check_in_time'];
      }
      if (updates.containsKey('check_out_time')) {
        columns['check_out_time'] = updates['check_out_time'];
      }
      if (updates.containsKey('status')) {
        columns['status'] = updates['status'];
      }
      if (updates.containsKey('notes')) {
        columns['notes'] = _normalize(updates['notes']);
      }
      if (updates.containsKey('guard_name')) {
        columns['guard_name'] = _normalize(updates['guard_name']);
      }
      if (updates.containsKey('is_early_leave')) {
        columns['is_early_leave'] = _int(updates['is_early_leave']);
      }

      columns['updated_at'] = _nowIso();

      final changed = await _db.update(
        _attendance,
        columns,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const ApiException(LangKeys.errorNotFound);

      final updated = await _recordById(id);
      if (updated == null) throw const ApiException(LangKeys.errorNotFound);
      return updated;
    });
  }

  /// Early leaves inside a calendar month, counted by SQLite rather than by
  /// pulling the month down and filtering in Dart.
  Future<int> countMonthlyEarlyLeaves(
    String employeeId,
    String yearMonth,
  ) async {
    return _guard(() async {
      final result = await _db.rawQuery(
        '''
        SELECT COUNT(*) AS c FROM $_attendance
        WHERE employee_id = ?
          AND date LIKE ?
          AND (is_early_leave = 1 OR status = 'early_leave')
        ''',
        [employeeId, '$yearMonth-%'],
      );
      return (result.first['c'] as int?) ?? 0;
    });
  }

  // --------------------------------------------------------------- helpers

  Future<List<EmployeeModel>> _employeeList({required bool activeOnly}) {
    return _guard(() async {
      final rows = await _db.query(
        _employees,
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'full_name COLLATE NOCASE ASC',
      );
      return rows.map(EmployeeModel.fromJson).toList();
    });
  }

  /// Joins the employee name in so the list screens keep showing it without a
  /// second query per row.
  Future<List<AttendanceRecordModel>> _recordList({
    String? where,
    List<Object?> args = const [],
    int? limit,
  }) {
    return _guard(() async {
      final rows = await _db.rawQuery('''
        SELECT r.*, e.full_name AS employee_name
        FROM $_attendance r
        LEFT JOIN $_employees e ON e.id = r.employee_id
        ${where == null ? '' : 'WHERE $where'}
        ORDER BY r.date DESC, r.check_in_time ASC
        ${limit == null ? '' : 'LIMIT $limit'}
        ''', args);
      return rows.map(AttendanceRecordModel.fromJson).toList();
    });
  }

  Future<AttendanceRecordModel?> _recordById(String id) async {
    final rows = await _recordList(where: 'r.id = ?', args: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> _employeeExists(String id) async {
    final rows = await _db.query(
      _employees,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _employeeNumberTaken(String number, String? exceptId) async {
    final rows = await _db.query(
      _employees,
      columns: ['id'],
      where: 'employee_number = ?${exceptId == null ? '' : ' AND id != ?'}',
      whereArgs: [number, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _deviceUserIdTaken(String deviceUserId, String? exceptId) async {
    final rows = await _db.query(
      _employees,
      columns: ['id'],
      where: 'device_user_id = ?${exceptId == null ? '' : ' AND id != ?'}',
      whereArgs: [deviceUserId, ?exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// The working hours this employee's day is judged by: their shift's, or the
  /// company default when they are on none — or on one that has since been
  /// deleted, which the left join resolves to the same thing.
  ///
  /// Read in SQL rather than through the shifts repo so a correction costs one
  /// query, and so the answer is built by exactly the code the device fold
  /// uses; see [ShiftModel.scheduleFromRow].
  Future<WorkSchedule> _scheduleFor(String employeeId) async {
    final companyDefault = _readSchedule?.call() ?? kDefaultSchedule;

    final rows = await _db.rawQuery(
      '''
      SELECT s.start_work, s.end_work,
             s.late_grace_minutes, s.early_out_grace_minutes, s.rest_days
        FROM $_employees e
        LEFT JOIN shifts s ON s.id = e.shift_id
       WHERE e.id = ?
       LIMIT 1
    ''',
      [employeeId],
    );

    if (rows.isEmpty) return companyDefault;
    return ShiftModel.scheduleFromRow(rows.first, companyDefault);
  }

  static String? _normalize(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _int(Object? value, {int fallback = 0}) => switch (value) {
    bool v => v ? 1 : 0,
    int v => v == 0 ? 0 : 1,
    _ => fallback,
  };

  static String _nowIso() => DateTime.now().toIso8601String();

  /// Wraps a database call so callers only ever see [ApiException], exactly as
  /// they did when the failures came from Dio.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const ApiException(LangKeys.errorDuplicateRecord);
      }
      throw ApiException(LangKeys.errorDatabase, detail: e.toString());
    } catch (e) {
      throw ApiException(LangKeys.errorUnknown, detail: e.toString());
    }
  }
}
