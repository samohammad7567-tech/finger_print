import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../attendance/data/models/employee_import_models.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../attendance/data/repos/attendance_repo.dart';
import '../../../device/data/repos/device_repo.dart';
import '../../data/data_source/employee_import_excel_data_source.dart';
import '../../data/repos/employee_import_repo.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/localization/lang_keys.dart';

class EmployeeManagementState {
  final List<EmployeeModel> employees;
  final bool isLoading;
  final bool isSaving;
  final bool isDeleting;

  /// Reading a workbook and creating everybody in it, which takes long enough
  /// on a real staff list that the button has to say so.
  final bool isImporting;

  final String search;
  final String? errorKey;
  final String? successKey;
  final EmployeeModel? lastAddedEmployee;

  /// What the last import did — who was created, and which rows were refused
  /// and why. Held only until the screen has shown it, like the other feedback
  /// on this state.
  final EmployeeImportResult? importResult;

  /// Terminal users the device sync held back because they share a name with
  /// somebody in this list. Nothing has been created for them, so without a
  /// count here their absence reads as the sync having failed.
  final int pendingMatchCount;

  /// Pulling the enrolment list off the terminal, which takes a moment on a
  /// device that has to be woken up first.
  final bool isFetchingFromDevice;

  /// What the last fetch created, how many it held back for review, who it
  /// refused as previously deleted, and how many the terminal gave it at all.
  final DeviceFetchOutcome? deviceFetchResult;

  /// Set when a fetch found people on the terminal that it may not import
  /// because they were deleted here before. Opens the restore dialog once.
  final bool deletedNeedReview;

  /// Employees who answer to the same name. Not an error and not something the
  /// app may settle on its own — the dialog puts them in front of the admin so
  /// they can write a name that tells the two apart.
  final List<EmployeeNameClash> nameClashes;

  /// Set once a fetch has finished with clashes to report, so the screen opens
  /// the dialog once rather than on every rebuild.
  final bool clashesNeedReview;

  const EmployeeManagementState({
    this.employees = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.isDeleting = false,
    this.isImporting = false,
    this.search = '',
    this.errorKey,
    this.successKey,
    this.lastAddedEmployee,
    this.importResult,
    this.pendingMatchCount = 0,
    this.isFetchingFromDevice = false,
    this.deviceFetchResult,
    this.deletedNeedReview = false,
    this.nameClashes = const [],
    this.clashesNeedReview = false,
  });

  List<EmployeeModel> get filtered {
    if (search.isEmpty) return employees;
    final q = search.toLowerCase();
    return employees
        .where(
          (e) =>
              e.fullName.toLowerCase().contains(q) ||
              (e.employeeId?.contains(q) ?? false) ||
              e.department.toLowerCase().contains(q),
        )
        .toList();
  }

  bool get hasEmployees => employees.isNotEmpty;
  bool get hasActiveEmployees => employees.any((e) => e.isActive);
  bool get hasPendingMatches => pendingMatchCount > 0;
  bool get hasNameClashes => nameClashes.isNotEmpty;

  /// Any long-running write. The fetch and the import both rewrite the list, so
  /// neither may start while the other is running.
  bool get isBusy =>
      isSaving || isDeleting || isImporting || isFetchingFromDevice;

  EmployeeManagementState copyWith({
    List<EmployeeModel>? employees,
    bool? isLoading,
    bool? isSaving,
    bool? isDeleting,
    bool? isImporting,
    String? search,
    String? errorKey,
    String? successKey,
    EmployeeModel? lastAddedEmployee,
    EmployeeImportResult? importResult,
    int? pendingMatchCount,
    bool? isFetchingFromDevice,
    DeviceFetchOutcome? deviceFetchResult,
    bool? deletedNeedReview,
    List<EmployeeNameClash>? nameClashes,
    bool? clashesNeedReview,
  }) => EmployeeManagementState(
    employees: employees ?? this.employees,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isDeleting: isDeleting ?? this.isDeleting,
    isImporting: isImporting ?? this.isImporting,
    search: search ?? this.search,
    errorKey: errorKey,
    successKey: successKey,
    lastAddedEmployee: lastAddedEmployee,
    importResult: importResult,
    pendingMatchCount: pendingMatchCount ?? this.pendingMatchCount,
    isFetchingFromDevice: isFetchingFromDevice ?? this.isFetchingFromDevice,
    // Cleared alongside the other feedback, so a result is reported once.
    deviceFetchResult: deviceFetchResult,
    deletedNeedReview: deletedNeedReview ?? this.deletedNeedReview,
    nameClashes: nameClashes ?? this.nameClashes,
    clashesNeedReview: clashesNeedReview ?? this.clashesNeedReview,
  );
}

class EmployeeManagementCubit extends Cubit<EmployeeManagementState> {
  final AttendanceRepo _repo;
  final DeviceRepo _device;
  final EmployeeImportRepo _import;

  EmployeeManagementCubit(this._repo, this._device, this._import)
    : super(const EmployeeManagementState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, errorKey: null));
    try {
      final employees = await _repo.getAllEmployees();
      emit(
        state.copyWith(
          employees: employees,
          isLoading: false,
          pendingMatchCount: await _pendingMatchCount(),
          nameClashes: await _nameClashes(),
          errorKey: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorKey: LangKeys.failedLoadEmployees,
        ),
      );
    }
  }

  /// Never allowed to fail the screen: the banner is a helpful aside, and the
  /// employee list is the reason anybody came here.
  Future<int> _pendingMatchCount() async {
    try {
      return await _device.pendingMatchCount();
    } catch (_) {
      return 0;
    }
  }

  /// As above — a clash the admin has not been shown yet is worth less than the
  /// list itself, so it never takes the screen down with it.
  Future<List<EmployeeNameClash>> _nameClashes() async {
    try {
      return await _repo.findNameClashes();
    } catch (_) {
      return const [];
    }
  }

  /// The staff number the next new employee will get.
  Future<String> nextEmployeeNumber() => _repo.nextEmployeeNumber();

  void setSearch(String value) => emit(state.copyWith(search: value));

  /// Clears success/error messages after they've been shown.
  void clearFeedback() => emit(
    state.copyWith(errorKey: null, successKey: null, lastAddedEmployee: null),
  );

  /// The dialog has been shown, so it must not open itself again on the next
  /// rebuild. The clashes themselves stay in state — the list keeps flagging
  /// them until somebody actually renames one.
  void clashesReviewed() => emit(state.copyWith(clashesNeedReview: false));

  // ----------------------------------------------------------- from device

  /// Fills the staff list in from the terminal's own enrolment table.
  ///
  /// Three steps that have to happen in this order. Fetching creates everybody
  /// the terminal knows about and the app plainly does not — holding back
  /// anyone who looks like somebody already here, which is what stops the
  /// duplicates. Renumbering then folds the new arrivals into one sequence with
  /// the people already on file, so the list reads 001..N however it was filled
  /// in. Only then is it worth looking for names that now appear twice, because
  /// until the fetch has run there is nothing new to clash with.
  Future<void> fetchFromDevice() async {
    if (state.isBusy) return;

    final settings = _device.readSettings();
    if (!settings.isConfigured) {
      emit(state.copyWith(errorKey: LangKeys.errorDeviceNotConfigured));
      return;
    }

    emit(
      state.copyWith(
        isFetchingFromDevice: true,
        errorKey: null,
        successKey: null,
      ),
    );

    try {
      final raw = await _device.fetchEmployees(settings);
      final outcome = DeviceFetchOutcome(
        created: raw.created,
        pending: raw.pending,
        readFromDevice: raw.readFromDevice,
        deleted: [
          for (final user in raw.dismissed)
            (deviceUserId: user.deviceUserId, name: user.name),
        ],
      );

      await _repo.resequenceEmployeeNumbers();
      await load();

      emit(
        state.copyWith(
          isFetchingFromDevice: false,
          deviceFetchResult: outcome,
          clashesNeedReview: state.nameClashes.isNotEmpty,
          // The confusing case, and the one that brought this on: the terminal
          // has people on it, none of them may be imported, and the count alone
          // makes it look as though the fetch did nothing.
          deletedNeedReview: outcome.hasDeleted,
          successKey: LangKeys.deviceFetchDone,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isFetchingFromDevice: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(
          isFetchingFromDevice: false,
          errorKey: LangKeys.errorUnknown,
        ),
      );
    }
  }

  /// The restore dialog has been shown, so it does not open itself again.
  void deletedReviewed() => emit(state.copyWith(deletedNeedReview: false));

  /// Lifts the deletion on people the terminal still knows about, then fetches
  /// them straight back in.
  ///
  /// Deleting an employee tombstones their terminal id so the next automatic
  /// sync cannot quietly undo the deletion — that rule is worth keeping, and it
  /// stays. What it must not be is one-way: somebody who left and came back is
  /// enrolled under the same id, and until now there was no way to say so.
  Future<void> restoreDeletedDeviceUsers(List<String> deviceUserIds) async {
    if (deviceUserIds.isEmpty || state.isBusy) return;

    emit(
      state.copyWith(
        isFetchingFromDevice: true,
        errorKey: null,
        successKey: null,
      ),
    );
    try {
      await _device.restoreDeviceUsers(deviceUserIds);
      emit(state.copyWith(isFetchingFromDevice: false));
      await fetchFromDevice();
    } on ApiException catch (e) {
      emit(state.copyWith(isFetchingFromDevice: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(
          isFetchingFromDevice: false,
          errorKey: LangKeys.errorUnknown,
        ),
      );
    }
  }

  /// Writes the name the admin chose for one of a clashing pair.
  ///
  /// The point of the dialog: the two records stay two people, but the list can
  /// finally tell you which is which. Re-reading the clashes afterwards is what
  /// makes a resolved one disappear.
  Future<void> renameEmployee(String id, String fullName) async {
    final name = fullName.trim();
    if (name.isEmpty) return;

    emit(state.copyWith(isSaving: true, errorKey: null, successKey: null));
    try {
      await _repo.updateEmployee(id, {'full_name': name});
      await load();
      emit(
        state.copyWith(isSaving: false, successKey: LangKeys.employeeUpdated),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, errorKey: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isSaving: false, errorKey: LangKeys.failedSaveEmployee),
      );
    }
  }

  // ------------------------------------------------------------ excel import

  /// Adds everybody named in a workbook the admin picks.
  ///
  /// The list is reloaded before the report is emitted, so the screen behind
  /// the report already shows the new people — and so [load] cannot wipe the
  /// report on its way past.
  Future<void> importFromExcel({
    required String typeLabel,
    String? confirmLabel,
  }) async {
    if (state.isImporting) return;

    // Asked before the spinner goes up: the dialog is the admin's own time,
    // and closing it is an answer, not a failure.
    final String? path;
    try {
      path = await _import.pickFile(
        typeLabel: typeLabel,
        confirmLabel: confirmLabel,
      );
    } catch (_) {
      emit(state.copyWith(errorKey: LangKeys.importFailed));
      return;
    }
    if (path == null) return;

    emit(state.copyWith(isImporting: true, errorKey: null, successKey: null));
    try {
      final rows = await _import.read(path);
      if (rows.isEmpty) {
        emit(
          state.copyWith(isImporting: false, errorKey: LangKeys.importNoRows),
        );
        return;
      }

      final result = await _repo.importEmployees(rows);
      await load();
      emit(
        state.copyWith(
          isImporting: false,
          importResult: result,
          successKey: result.hasCreated ? LangKeys.importDone : null,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isImporting: false, errorKey: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isImporting: false, errorKey: LangKeys.importFailed));
    }
  }

  /// Saves a blank sheet with the headings the import understands, and opens
  /// it. Cheaper than telling somebody what to type and hoping.
  Future<void> saveImportTemplate({
    required EmployeeImportLabels labels,
    required String fileName,
    required String typeLabel,
    String? confirmLabel,
    bool isArabic = false,
  }) async {
    try {
      final path = await _import.pickTemplateDestination(
        fileName: fileName,
        typeLabel: typeLabel,
        confirmLabel: confirmLabel,
      );
      if (path == null) return;

      final file = await _import.writeTemplate(
        path: path,
        labels: labels,
        isArabic: isArabic,
      );
      emit(state.copyWith(successKey: LangKeys.importTemplateSaved));
      await _import.open(file.path);
    } catch (_) {
      emit(state.copyWith(errorKey: LangKeys.importTemplateFailed));
    }
  }

  Future<void> saveEmployee(Map<String, dynamic> data, {String? editId}) async {
    emit(state.copyWith(isSaving: true, errorKey: null, successKey: null));
    try {
      if (editId != null) {
        await _repo.updateEmployee(editId, data);
        emit(
          state.copyWith(isSaving: false, successKey: LangKeys.employeeUpdated),
        );
      } else {
        await _repo.createEmployee(data);
        emit(
          state.copyWith(isSaving: false, successKey: LangKeys.employeeAdded),
        );
      }

      // Refresh list after save
      await load();
    } catch (e) {
      emit(
        state.copyWith(isSaving: false, errorKey: LangKeys.failedSaveEmployee),
      );
    }
  }

  /// Deletes an employee here **and** on the terminal.
  ///
  /// Removing them locally alone was not enough: they stay enrolled on the
  /// device, so the employee import in the next sync recreates them and the
  /// deletion appears to undo itself. The device delete is attempted first, and
  /// either way the device id is tombstoned so the import leaves them alone.
  ///
  /// Returns false when the fingerprint could not be cleared from the terminal,
  /// so the UI can say so.
  Future<bool> deleteEmployee(String id) async {
    emit(state.copyWith(isDeleting: true, errorKey: null));
    var clearedFromDevice = true;
    try {
      final employee = state.employees.where((e) => e.id == id).firstOrNull;
      final deviceUserId = employee?.deviceUserId;

      if (deviceUserId != null && deviceUserId.isNotEmpty) {
        clearedFromDevice = await _device.deleteDeviceUser(deviceUserId);
      }

      await _repo.deleteEmployee(id);
      emit(
        state.copyWith(
          isDeleting: false,
          successKey: LangKeys.employeeDeleted,
          errorKey: null,
        ),
      );
    } catch (_) {
      clearedFromDevice = false;
      emit(
        state.copyWith(
          isDeleting: false,
          errorKey: LangKeys.failedDeleteEmployee,
        ),
      );
    }
    await load();
    return clearedFromDevice;
  }

  Future<void> toggleActive(EmployeeModel emp) async {
    emit(state.copyWith(errorKey: null));
    try {
      await _repo.updateEmployee(emp.id, {'is_active': !emp.isActive});
      emit(
        state.copyWith(
          successKey: emp.isActive
              ? LangKeys.employeeDeactivated
              : LangKeys.employeeActivated,
        ),
      );
      await load();
    } catch (_) {
      emit(state.copyWith(errorKey: LangKeys.failedUpdateEmployee));
      await load();
    }
  }
}

/// What one press of "From device" actually did.
///
/// Carries the raw count the terminal returned as well as the outcomes, so an
/// admin who sees nothing appear can tell "the device gave us nobody" apart
/// from "everybody it gave us is already here, or was deleted".
class DeviceFetchOutcome {
  /// Employees created this run.
  final int created;

  /// Held back because they share a name with somebody already on file.
  final int pending;

  /// Refused because an admin deleted them before. Still enrolled on the
  /// terminal, and restorable.
  final List<({String deviceUserId, String name})> deleted;

  /// How many people the terminal listed, before any of the above.
  final int readFromDevice;

  const DeviceFetchOutcome({
    this.created = 0,
    this.pending = 0,
    this.deleted = const [],
    this.readFromDevice = 0,
  });

  bool get hasDeleted => deleted.isNotEmpty;

  /// The terminal answered, but nothing came of it — the case worth explaining
  /// rather than reporting as a bare zero.
  bool get isPuzzling => created == 0 && readFromDevice > 0;
}
