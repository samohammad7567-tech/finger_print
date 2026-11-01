import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:intl/intl.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/attendance_utils.dart';
import '../../../../core/utils/punch_pairs.dart';
import '../../../../core/utils/work_schedule.dart';
import '../../../attendance/data/models/attendance_day_totals.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../device/data/repos/device_repo.dart';
import '../../../holidays/data/models/work_calendar.dart';
import '../../../holidays/data/repos/holidays_repo.dart';
import '../../../settings/data/repos/settings_repo.dart';
import '../../../shifts/data/models/shift_schedules.dart';
import '../../../shifts/data/repos/shifts_repo.dart';
import '../../data/data_source/monthly_punches_excel_data_source.dart';
import '../../data/data_source/punch_report_pdf_data_source.dart';
import '../../data/repos/monthly_punches_excel_repo.dart';
import '../../data/repos/punch_report_pdf_repo.dart';
import '../refactor/employee_pattern.dart';

/// The date filters offered above the report. [day] is one chosen date and
/// [custom] a range picked by hand; the rest are fixed spans.
enum PunchRangePreset { today, last7Days, thisMonth, lastMonth, day, custom }

/// Which side of the housing flag the report should keep.
enum PunchHousingFilter { all, housed, notHoused }

/// The scans the report should pair for one day.
///
/// Raw scans are the true sequence, so they win whenever they are available.
/// A corrected day is the exception: the admin's times are the record now, and
/// the report must not keep reading the device log over them. Days folded
/// before the log was queried — or typed by hand — are rebuilt from the stored
/// fields instead, so no report row is left blank for want of raw punches.
List<String> _scanTimes(
  AttendanceRecordModel record,
  List<String> raw,
  List<AttendanceBreak> breaks,
) {
  if (!record.isCorrected && raw.isNotEmpty) return raw;

  final scans = <String>[];
  void add(String? time) {
    final value = time?.trim() ?? '';
    if (value.isNotEmpty && !scans.contains(value)) scans.add(value);
  }

  add(record.checkInTime);
  for (final b in breaks) {
    add(b.out);
    add(b.backIn);
  }
  add(record.overtimeInTime);
  add(record.overtimeOutTime);
  add(record.checkOutTime);

  scans.sort((a, b) => timeToMinutes(a).compareTo(timeToMinutes(b)));
  return scans;
}

/// One row of the punch report: a person, a day, and what their scans add up
/// to once the admin's working hours are applied to them.
///
/// The arithmetic itself lives in [AttendanceDayTotals], which the monthly
/// summary reads too — one rule per figure, wherever it is shown.
class PunchReportRow {
  final EmployeeModel employee;
  final AttendanceRecordModel record;

  /// The raw scans behind this day, in order, when the caller has them.
  final List<String> punches;

  final AttendanceDayTotals totals;

  PunchReportRow({
    required this.employee,
    required this.record,
    this.punches = const [],
    WorkSchedule schedule = kDefaultSchedule,
    WorkingDayKind dayKind = WorkingDayKind.working,
  }) : totals = AttendanceDayTotals.forEmployee(
         record: record,
         employee: employee,
         schedule: schedule,
         dayKind: dayKind,
       );

  /// The day's scans, paired by their order: first in/out, second in/out, and
  /// so on. An odd last scan is a check-out on its own.
  ///
  /// Computed once: the table reads it for every pair column, and the exports
  /// read it again for every row.
  late final List<PunchPair> pairs = PunchPairs.fromOrdered(
    _scanTimes(record, punches, breaks),
  );

  /// The hours this day is judged against.
  WorkSchedule get schedule => totals.schedule;

  /// Everything unusual about the day, rather than the one word [status]
  /// collapses to — a person late in *and* early out carries both.
  List<AttendanceFlag> get flags => totals.flags;

  /// What the day should be labelled with: its flags, or its plain status when
  /// there is nothing unusual to say.
  List<String> get labelKeys => totals.labelKeys;

  /// Every break of the day.
  List<AttendanceBreak> get breaks => totals.breaks;

  /// Time away on breaks — every closed one of them, not just the first.
  Duration get breakTime => totals.breakTime;

  /// Ordinary work time, or null when the day has no pair of scans to measure
  /// or was missed altogether.
  Duration? get worked => totals.worked;

  /// Overtime inside the window the admin set.
  Duration? get overtime => totals.overtime;

  /// True when they first scanned after their working day had already ended.
  bool get isAbsentArrival => totals.isAbsentArrival;

  /// How late they were, past whatever their shift forgives. Zero when not.
  int get lateMinutes => totals.lateMinutes;

  /// How early they left, past whatever their shift forgives. Zero when not.
  int get earlyOutMinutes => totals.earlyOutMinutes;

  /// True when something about this day is worth an admin's attention.
  bool get hasIssue => totals.hasIssue;

  /// Whether the admin may still correct this day. Today's row, once.
  bool canCorrect(DateTime today) => record.canCorrectOn(today);

  /// True once the day's one correction has been spent.
  bool get isCorrected => record.isCorrected;

  /// What the day reads as, which is the stored status unless the times say
  /// the working day was missed.
  String get status => totals.status;

  /// The date this row is for.
  DateTime get day => totals.day;

  /// When this person's day was scheduled to end, on this row's date.
  int get scheduledEndMinutes => totals.endOfDayMinutes;

  /// The family name payroll knows them by, empty when nobody filled it in.
  String get surname => employee.surname?.trim() ?? '';

  /// Their personal / national id number, empty when nobody filled it in.
  String get personalId => employee.personalId?.trim() ?? '';

  /// Where they stay between shifts, as words. A person can carry both flags,
  /// so both are shown rather than one silently winning.
  ///
  /// [traveler] and [overnight] arrive already translated: the words belong to
  /// whoever is drawing the row, not to the row itself.
  String accommodationText({
    required String traveler,
    required String overnight,
  }) {
    final parts = <String>[
      if (employee.hasTravelPermission) traveler,
      if (employee.hasHousing) overnight,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

class PunchReportState {
  final List<PunchReportRow> rows;
  final List<EmployeeModel> employees;

  final DateTime start;
  final DateTime end;
  final PunchRangePreset preset;

  /// Empty means every employee.
  final String employeeFilter;

  /// Empty means every department.
  final String departmentFilter;

  /// Empty means every position.
  final String positionFilter;

  /// Which housing flag to keep. [PunchHousingFilter.all] keeps everybody.
  final PunchHousingFilter housingFilter;

  /// Show only days carrying something worth attention.
  ///
  /// A view over [rows] rather than a narrower query: the whole range is
  /// already loaded, and toggling this is meant to feel instant. It is also
  /// why [visibleRows] exists — everything the screen shows and everything it
  /// exports reads that, so what you see is what you get.
  final bool issuesOnly;

  final bool isLoading;

  /// A pull from the terminal is in flight. Separate from [isLoading] so the
  /// table stays on screen while it runs.
  final bool isSyncing;

  /// A PDF is being written. Its own flag so the button can say so.
  final bool isExporting;

  /// A correction is being saved.
  final bool isCorrecting;

  /// The monthly workbook is being written. Its own flag: it reads the whole
  /// month for everybody and takes visibly longer than the PDF.
  final bool isExportingExcel;

  /// The company's default working hours, so the screen can show which day it
  /// is judging people by.
  ///
  /// Only the people on no shift, once [hasShifts] is true — each row carries
  /// its own hours; see [PunchReportRow.schedule].
  final WorkSchedule schedule;

  /// True when the admin has set up at least one shift, and [schedule] is
  /// therefore the default rather than the rule for everybody. The header says
  /// so rather than claiming hours half the table was not measured against.
  final bool hasShifts;

  final String? error;
  final String? message;

  /// Fill-ins for [message], for the few that name something — the path a file
  /// was written to. Empty for the rest, which say all they need to on their
  /// own.
  final List<String> messageArgs;

  const PunchReportState({
    this.rows = const [],
    this.employees = const [],
    required this.start,
    required this.end,
    this.preset = PunchRangePreset.today,
    this.employeeFilter = '',
    this.departmentFilter = '',
    this.positionFilter = '',
    this.housingFilter = PunchHousingFilter.all,
    this.issuesOnly = false,
    this.isLoading = true,
    this.isSyncing = false,
    this.isExporting = false,
    this.isCorrecting = false,
    this.isExportingExcel = false,
    this.schedule = kDefaultSchedule,
    this.hasShifts = false,
    this.error,
    this.message,
    this.messageArgs = const [],
  });

  /// The rows the screen shows and the exports write — [rows] narrowed by the
  /// employee, department, position and housing filters, then the issues-only
  /// toggle.
  ///
  /// All of these are views over [rows] rather than narrower queries: the
  /// whole range is already loaded, and changing a filter is meant to feel
  /// instant.
  List<PunchReportRow> get visibleRows {
    final scoped = [
      for (final row in rows)
        if (_matchesEmployeeFilters(row)) row,
    ];

    return issuesOnly
        ? [
            for (final row in scoped)
              if (row.hasIssue) row,
          ]
        : scoped;
  }

  /// One line per person over the visible range, worst first.
  List<EmployeePattern> get patterns => EmployeePattern.from(visibleRows);

  /// How many of the days in the current employee scope carry something worth
  /// attention. Shown on the toggle so an admin knows whether turning it on
  /// will leave anything.
  int get issueCount =>
      rows.where((row) => row.hasIssue && _matchesEmployeeFilters(row)).length;

  /// The departments present in the loaded staff list, plus the one currently
  /// selected — so a filter that is somehow stale never leaves the dropdown
  /// without a matching item.
  List<String> get departmentOptions =>
      _options([departmentFilter, for (final e in employees) e.department]);

  /// The positions present in the loaded staff list, plus the current one.
  List<String> get positionOptions =>
      _options([positionFilter, for (final e in employees) e.position]);

  /// True when an employee, department, position or housing filter is set.
  bool get hasEmployeeFilters =>
      employeeFilter.isNotEmpty ||
      departmentFilter.isNotEmpty ||
      positionFilter.isNotEmpty ||
      housingFilter != PunchHousingFilter.all;

  bool _matchesEmployeeFilters(PunchReportRow row) {
    final employee = row.employee;

    if (employeeFilter.isNotEmpty && employee.id != employeeFilter) {
      return false;
    }
    if (departmentFilter.isNotEmpty &&
        _normalized(employee.department) != _normalized(departmentFilter)) {
      return false;
    }
    if (positionFilter.isNotEmpty &&
        _normalized(employee.position) != _normalized(positionFilter)) {
      return false;
    }

    return switch (housingFilter) {
      PunchHousingFilter.all => true,
      PunchHousingFilter.housed => employee.hasHousing,
      PunchHousingFilter.notHoused => !employee.hasHousing,
    };
  }

  /// Distinct, non-empty values in display casing, sorted case-insensitively.
  static List<String> _options(Iterable<String?> values) {
    final byKey = <String, String>{};
    for (final raw in values) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) continue;
      byKey.putIfAbsent(value.toLowerCase(), () => value);
    }
    return byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static String _normalized(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// The widest day on screen, in scan pairs. Every output uses it so the
  /// columns run from the first check-in to the last check-out of anybody in
  /// the range, and no row is cut short.
  int get maxPairs {
    var count = 1;
    for (final row in visibleRows) {
      if (row.pairs.length > count) count = row.pairs.length;
    }
    return count;
  }

  Duration get totalWorked => visibleRows.fold(
    Duration.zero,
    (sum, r) => sum + (r.worked ?? Duration.zero),
  );

  Duration get totalOvertime => visibleRows.fold(
    Duration.zero,
    (sum, r) => sum + (r.overtime ?? Duration.zero),
  );

  Duration get totalBreakTime =>
      visibleRows.fold(Duration.zero, (sum, r) => sum + r.breakTime);

  PunchReportState copyWith({
    List<PunchReportRow>? rows,
    List<EmployeeModel>? employees,
    DateTime? start,
    DateTime? end,
    PunchRangePreset? preset,
    String? employeeFilter,
    String? departmentFilter,
    String? positionFilter,
    PunchHousingFilter? housingFilter,
    bool? issuesOnly,
    bool? isLoading,
    bool? isSyncing,
    bool? isExporting,
    bool? isCorrecting,
    bool? isExportingExcel,
    WorkSchedule? schedule,
    bool? hasShifts,
    String? error,
    String? message,
    List<String>? messageArgs,
    bool clearError = false,
    bool clearMessage = false,
  }) => PunchReportState(
    rows: rows ?? this.rows,
    employees: employees ?? this.employees,
    start: start ?? this.start,
    end: end ?? this.end,
    preset: preset ?? this.preset,
    employeeFilter: employeeFilter ?? this.employeeFilter,
    departmentFilter: departmentFilter ?? this.departmentFilter,
    positionFilter: positionFilter ?? this.positionFilter,
    housingFilter: housingFilter ?? this.housingFilter,
    issuesOnly: issuesOnly ?? this.issuesOnly,
    isLoading: isLoading ?? this.isLoading,
    isSyncing: isSyncing ?? this.isSyncing,
    isExporting: isExporting ?? this.isExporting,
    isCorrecting: isCorrecting ?? this.isCorrecting,
    isExportingExcel: isExportingExcel ?? this.isExportingExcel,
    schedule: schedule ?? this.schedule,
    hasShifts: hasShifts ?? this.hasShifts,
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
    messageArgs: clearMessage ? const [] : (messageArgs ?? this.messageArgs),
  );
}

/// Builds the punch report over a date range, and pulls fresh punches off the
/// terminal on demand.
class PunchReportCubit extends Cubit<PunchReportState> {
  final AttendanceRepo _repo;
  final DeviceRepo _device;
  final SettingsRepo _settings;
  final ShiftsRepo _shifts;
  final HolidaysRepo _holidays;
  final PunchReportPdfRepo _pdf;
  final MonthlyPunchesExcelRepo _excel;

  PunchReportCubit(
    this._repo,
    this._device,
    this._settings,
    this._shifts,
    this._holidays,
    this._pdf,
    this._excel,
  ) : super(
        PunchReportState(start: _dayStart(DateTime.now()), end: DateTime.now()),
      );

  /// One row, judged by this person's own shift and by whether the date was a
  /// day they were expected to work at all.
  ///
  /// Shared by the table and the monthly workbook so the two can never
  /// disagree about whether a Friday counted.
  static PunchReportRow _rowFor(
    EmployeeModel employee,
    AttendanceRecordModel record,
    ShiftSchedules schedules,
    WorkCalendar calendar, {
    List<String> punches = const [],
  }) {
    final schedule = schedules.of(employee);
    return PunchReportRow(
      employee: employee,
      record: record,
      punches: punches,
      schedule: schedule,
      dayKind: calendar.kindOfDate(record.date, schedule),
    );
  }

  /// [silent] keeps the table on screen instead of replacing it with a
  /// spinner — what a refresh wants, since it already has its own.
  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(isLoading: true, clearError: true));
    try {
      // Read every time: the admin may have changed the hours or the shifts
      // since the last load, and every figure below is measured against them.
      final schedules = await _shifts.getSchedules();
      // Which of these dates anybody was expected to work. Read alongside the
      // shifts so a whole range is judged against one reading of both.
      final calendar = await _holidays.getCalendar();

      final employees = await _repo.getAllEmployees();
      final records = await _repo.getRecordsByDateRange(
        _iso(state.start),
        _iso(state.end),
      );
      final punches = await _device.punchTimesByDay(
        _iso(state.start),
        _iso(state.end),
      );

      final byId = {for (final e in employees) e.id: e};

      final rows =
          records
              .map((r) {
                final employee = byId[r.employeeId];
                return employee == null
                    ? null
                    : _rowFor(
                        employee,
                        r,
                        schedules,
                        calendar,
                        punches:
                            punches['${r.employeeId}|${r.date}'] ?? const [],
                      );
              })
              .whereType<PunchReportRow>()
              .toList()
            // Newest day first, then by name so a day reads in a stable order.
            ..sort((a, b) {
              final byDate = b.record.date.compareTo(a.record.date);
              return byDate != 0
                  ? byDate
                  : a.employee.fullName.compareTo(b.employee.fullName);
            });

      // The selected person may have been deleted while this screen was open.
      // Dropping a filter that no longer matches anybody is better than leaving
      // the screen stuck on an empty table with a name the report cannot show.
      final employeeFilter = employees.any((e) => e.id == state.employeeFilter)
          ? state.employeeFilter
          : '';

      emit(
        state.copyWith(
          rows: rows,
          employees: employees,
          employeeFilter: employeeFilter,
          // The company default, shown in the header as the day anybody without
          // a shift works. Each row carries its own hours; see [PunchReportRow].
          schedule: schedules.companyDefault,
          hasShifts: !schedules.isEmpty,
          isLoading: false,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: LangKeys.errorUnknown));
    }
  }

  /// Pulls whatever the terminal has, re-reads the punches already stored for
  /// the range on screen, then rebuilds the report.
  ///
  /// The re-read matters as much as the pull: it is what applies the current
  /// check-in / break / overtime rules to days folded earlier.
  Future<void> refreshFromDevice() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true, clearError: true, clearMessage: true));

    String? error;
    try {
      final settings = _device.readSettings();
      if (settings.isConfigured) {
        await _device.sync(settings);
      } else {
        // Still worth rebuilding from what is stored, so say what is missing
        // rather than failing outright.
        error = LangKeys.errorDeviceNotConfigured;
      }
      await _device.refoldRange(_iso(state.start), _iso(state.end));
    } on ApiException catch (e) {
      error = e.errorKey;
    } catch (_) {
      error = LangKeys.errorUnknown;
    }

    emit(
      state.copyWith(
        isSyncing: false,
        error: error,
        message: error == null ? LangKeys.reportRefreshed : null,
      ),
    );
    await load(silent: true);
    _clearMessage();
  }

  /// Writes the rows on screen to a PDF and hands it to the machine's viewer.
  ///
  /// [labels] arrive already translated and [locale] names the days, because
  /// the words on the page belong to the screen that asked for it, not here.
  Future<void> exportPdf({
    required PunchReportPdfLabels labels,
    required String locale,
    required bool isArabic,
  }) async {
    if (state.isExporting || state.visibleRows.isEmpty) return;
    emit(
      state.copyWith(isExporting: true, clearError: true, clearMessage: true),
    );

    try {
      final dayFormat = DateFormat('EEEE', locale);

      final rows = <PunchReportPdfRow>[];
      for (final (index, r) in state.visibleRows.indexed) {
        rows.add(
          PunchReportPdfRow(
            serial: index + 1,
            surname: r.surname,
            name: r.employee.fullName,
            personalId: r.personalId,
            accommodation: r.accommodationText(
              traveler: labels.traveler,
              overnight: labels.overnight,
            ),
            date: r.record.date,
            dayName: dayFormat.format(r.day),
            pairs: r.pairs,
          ),
        );
      }

      final file = await _pdf.write(
        rows: rows,
        labels: labels,
        isArabic: isArabic,
        fileName: 'punch-report-${_iso(state.start)}_${_iso(state.end)}.pdf',
        totals: [
          '${labels.workTime}: ${_hm(state.totalWorked)}',
          '${labels.breakTime}: ${_hm(state.totalBreakTime)}',
          '${labels.overtime}: ${_hm(state.totalOvertime)}',
        ],
      );

      emit(
        state.copyWith(isExporting: false, message: LangKeys.reportPdfSaved),
      );
      await _pdf.open(file.path);
      _clearMessage();
    } catch (_) {
      emit(state.copyWith(isExporting: false, error: LangKeys.reportPdfFailed));
    }
  }

  /// Applies the admin's one correction to a day and rebuilds the report.
  ///
  /// The rule itself is not checked here. The data source owns it, so a stale
  /// screen — one left open past midnight, say — is refused by the thing that
  /// writes rather than waved through by the thing that draws.
  Future<void> correctPunches({
    required String recordId,
    String? checkIn,
    String? checkOut,
    String? correctedBy,
  }) async {
    if (state.isCorrecting) return;
    emit(
      state.copyWith(isCorrecting: true, clearError: true, clearMessage: true),
    );

    try {
      await _repo.correctPunches(
        recordId: recordId,
        checkInTime: checkIn,
        checkOutTime: checkOut,
        correctedBy: correctedBy,
      );
      emit(
        state.copyWith(
          isCorrecting: false,
          message: LangKeys.reportCorrectionSaved,
        ),
      );
      await load(silent: true);
      _clearMessage();
    } on ApiException catch (e) {
      emit(state.copyWith(isCorrecting: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isCorrecting: false, error: LangKeys.errorUnknown));
    }
  }

  /// Writes every employee's whole month to a workbook, day by day.
  ///
  /// The month is the one the report is showing: whichever range is on screen,
  /// the file covers the entire calendar month that range starts in — a
  /// one-day view still produces a full month, because a month is what an
  /// argument about a payslip is actually about.
  ///
  /// The employee filter is deliberately ignored. The file exists to answer
  /// "is my month right?", and one that quietly left somebody out would be
  /// worth nothing as evidence.
  ///
  /// The admin chooses where it goes. The dialog opens on the folder they
  /// used last time, and closing it calls the whole thing off.
  ///
  /// [labels] arrive already translated, because none of that is this layer's
  /// business.
  Future<void> exportMonthlyExcel({
    required MonthlyPunchesExcelLabels labels,
    required String locale,
    required bool isArabic,
    required String saveLabel,
  }) async {
    if (state.isExportingExcel) return;

    final month = DateTime(state.start.year, state.start.month);
    final fileName =
        'monthly-punches-${month.year}-'
        '${month.month.toString().padLeft(2, '0')}.xlsx';

    // Asked before the work rather than after it: reading a whole month for
    // everybody takes a moment, and nobody should sit through that only to
    // close the dialog at the end of it.
    String? destination;
    try {
      destination = await _excel.pickDestination(
        fileName: fileName,
        typeLabel: labels.title,
        initialDirectory: _settings.getLastExportFolder(),
        confirmLabel: saveLabel,
      );
      // Closing the dialog is an answer, not a failure. Nothing is written and
      // nothing is said about it.
      if (destination == null) return;
    } catch (_) {
      // No save dialog on this machine. Falling back to the reports folder is
      // better than refusing to export at all.
      destination = null;
    }

    emit(
      state.copyWith(
        isExportingExcel: true,
        clearError: true,
        clearMessage: true,
      ),
    );

    try {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final monthEnd = DateTime(month.year, month.month, lastDay);

      final schedules = await _shifts.getSchedules();
      final calendar = await _holidays.getCalendar();
      final employees = await _repo.getAllEmployees();
      final records = await _repo.getRecordsByDateRange(
        _iso(month),
        _iso(monthEnd),
      );
      final punches = await _device.punchTimesByDay(
        _iso(month),
        _iso(monthEnd),
      );

      final dayFormat = DateFormat('EEEE', locale);
      final ordered = [...employees]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      final sheets = <MonthlyPunchEmployee>[];

      for (final employee in ordered) {
        final byDate = {
          for (final r in records.where((r) => r.employeeId == employee.id))
            r.date: r,
        };

        var worked = Duration.zero;
        var breaks = Duration.zero;
        var overtime = Duration.zero;
        var presentDays = 0;
        var absentDays = 0;

        final rows = <MonthlyPunchRow>[];

        for (var number = 1; number <= lastDay; number++) {
          final day = DateTime(month.year, month.month, number);
          final date = _iso(day);
          final record = byDate[date];
          final dayName = dayFormat.format(day);

          // A day nobody scanned still gets a line. Silence is exactly what
          // people argue about, so the file has to show it rather than skip
          // over it and leave a gap that reads like an oversight.
          if (record == null) {
            // A day nobody scanned still gets a line, with blank pairs. That
            // absence is exactly what people argue about, so it is shown
            // rather than skipped over.
            rows.add(
              MonthlyPunchRow(date: date, dayName: dayName, pairs: const []),
            );
            continue;
          }

          final schedule = schedules.of(employee);
          final totals = AttendanceDayTotals.forEmployee(
            record: record,
            employee: employee,
            schedule: schedule,
            dayKind: calendar.kindOfDate(date, schedule),
          );

          worked += totals.worked ?? Duration.zero;
          breaks += totals.breakTime;
          overtime += totals.overtime ?? Duration.zero;

          final status = totals.status;
          if (!isWorkingDay(totals.dayKind)) {
            // Worked or not, a day off counts towards neither tally — it was
            // never one of the month's working days.
          } else if (status == 'absent') {
            absentDays++;
          } else if (record.checkInTime != null ||
              record.checkOutTime != null) {
            presentDays++;
          }

          final rawPunches =
              punches['${employee.id}|$date'] ?? const <String>[];

          rows.add(
            MonthlyPunchRow(
              date: date,
              dayName: dayName,
              pairs: PunchPairs.fromOrdered(
                _scanTimes(record, rawPunches, totals.breaks),
              ),
              corrected: record.isCorrected
                  ? (record.correctedBy?.trim().isNotEmpty == true
                        ? record.correctedBy!
                        : '✔')
                  : '',
            ),
          );
        }

        sheets.add(
          MonthlyPunchEmployee(
            name: employee.fullName,
            surname: employee.surname?.trim() ?? '',
            personalId: employee.personalId?.trim() ?? '',
            accommodation: _accommodationText(employee, labels),
            number: employee.employeeId ?? '',
            department: employee.department,
            rows: rows,
            totals: [
              (label: labels.worked, value: _hm(worked)),
              (label: labels.breakTime, value: _hm(breaks)),
              (label: labels.overtime, value: _hm(overtime)),
              (label: labels.presentDays, value: '$presentDays'),
              (label: labels.absentDays, value: '$absentDays'),
            ],
          ),
        );
      }

      final file = await _excel.write(
        employees: sheets,
        labels: labels,
        isArabic: isArabic,
        fileName: fileName,
        path: destination,
      );

      // Where it actually landed, which is the folder the dialog opens on next
      // month — and the fallback folder too, when there was no dialog.
      await _settings.setLastExportFolder(file.parent.path);

      emit(
        state.copyWith(
          isExportingExcel: false,
          message: LangKeys.reportMonthlySaved,
          messageArgs: [file.path],
        ),
      );
      await _excel.open(file.path);
      _clearMessage();
    } catch (_) {
      emit(
        state.copyWith(
          isExportingExcel: false,
          error: LangKeys.reportMonthlyFailed,
        ),
      );
    }
  }

  Future<void> showToday() {
    final now = DateTime.now();
    return _apply(PunchRangePreset.today, _dayStart(now), now);
  }

  Future<void> showLast7Days() {
    final now = DateTime.now();
    return _apply(
      PunchRangePreset.last7Days,
      _dayStart(now).subtract(const Duration(days: 6)),
      now,
    );
  }

  Future<void> showThisMonth() {
    final now = DateTime.now();
    return _apply(
      PunchRangePreset.thisMonth,
      DateTime(now.year, now.month, 1),
      now,
    );
  }

  Future<void> showLastMonth() {
    final now = DateTime.now();
    return _apply(
      PunchRangePreset.lastMonth,
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
  }

  /// One chosen date — the day-by-day view of the report.
  Future<void> showDay(DateTime day) =>
      _apply(PunchRangePreset.day, _dayStart(day), _dayStart(day));

  Future<void> setRange(DateTime start, DateTime end) =>
      _apply(PunchRangePreset.custom, start, end);

  /// The employee, department, position and housing filters all narrow the
  /// loaded rows rather than re-querying, so they are instant and keep the
  /// table, totals, patterns and exports in step.
  void setEmployee(String employeeId) =>
      emit(state.copyWith(employeeFilter: employeeId));

  void setDepartment(String department) =>
      emit(state.copyWith(departmentFilter: department));

  void setPosition(String position) =>
      emit(state.copyWith(positionFilter: position));

  void setHousing(PunchHousingFilter value) =>
      emit(state.copyWith(housingFilter: value));

  void clearEmployeeFilters() => emit(
    state.copyWith(
      employeeFilter: '',
      departmentFilter: '',
      positionFilter: '',
      housingFilter: PunchHousingFilter.all,
    ),
  );

  /// Narrows the table to the days worth looking at.
  ///
  /// No reload: the whole range is already in hand and this is a view over it,
  /// so the table, the totals and the exports all narrow together the instant
  /// it is tapped.
  void setIssuesOnly(bool value) => emit(state.copyWith(issuesOnly: value));

  Future<void> _apply(
    PunchRangePreset preset,
    DateTime start,
    DateTime end,
  ) async {
    emit(state.copyWith(preset: preset, start: start, end: end));
    await load();
  }

  /// A one-shot banner: the UI shows it, then it clears itself so returning to
  /// the screen later does not replay a stale success message.
  void _clearMessage() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!isClosed && state.message != null) {
        emit(state.copyWith(clearMessage: true));
      }
    });
  }

  /// The report as CSV, for the admin to hand to payroll.
  ///
  /// One pair of columns per scan pair, wide enough for the busiest day in the
  /// range. A day with fewer scans gets empty cells rather than a shorter line,
  /// so every row stays aligned in a spreadsheet.
  String toCsv() {
    final pairCount = state.maxPairs;
    final headers = <String>[
      'No.',
      'Surname',
      'Full Name',
      'Personal ID',
      'Accommodation',
      'Date',
    ];

    for (var i = 1; i <= pairCount; i++) {
      headers
        ..add(switch (i) {
          1 => 'First Check In',
          2 => 'Second Check In',
          _ => 'Check In $i',
        })
        ..add(switch (i) {
          1 => 'First Check Out',
          2 => 'Second Check Out',
          _ => 'Check Out $i',
        });
    }

    final buffer = StringBuffer()..writeln(headers.join(','));

    for (final (index, row) in state.visibleRows.indexed) {
      final cells = <String>[
        '${index + 1}',
        _csv(row.surname),
        _csv(row.employee.fullName),
        _csv(row.personalId),
        _csv(
          row.accommodationText(
            traveler: 'Traveler',
            overnight: 'Overnight stay',
          ),
        ),
        row.record.date,
      ];

      for (var i = 0; i < pairCount; i++) {
        final pair = i < row.pairs.length ? row.pairs[i] : null;
        cells
          ..add(pair?.checkIn ?? '')
          ..add(pair?.checkOut ?? '');
      }

      buffer.writeln(cells.join(','));
    }
    return buffer.toString();
  }

  static String _accommodationText(
    EmployeeModel employee,
    MonthlyPunchesExcelLabels labels,
  ) {
    final parts = <String>[
      if (employee.hasTravelPermission) labels.traveler,
      if (employee.hasHousing) labels.overnight,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static String _csv(String value) => value.contains(',') || value.contains('"')
      ? '"${value.replaceAll('"', '""')}"'
      : value;

  /// For the page rather than a spreadsheet cell: readable, not parseable.
  static String _hm(Duration d) =>
      '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

  static DateTime _dayStart(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
