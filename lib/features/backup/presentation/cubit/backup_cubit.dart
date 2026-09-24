import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/data_maintenance_models.dart';
import '../../data/repos/backup_repo.dart';

class BackupState {
  /// Where the live database file sits, shown so an admin can find it.
  final String? databasePath;

  /// Full path of the copy written by the last successful backup.
  final String? lastBackupPath;

  /// What the database is holding right now. Null until the first read.
  final DataFootprint? footprint;

  final bool isSaving;
  final bool isRestoring;

  /// A purge or a full erase. Both rewrite the whole file, so neither may run
  /// while the other does.
  final bool isClearing;

  /// A backup the admin has chosen but not yet confirmed. Handed to the screen
  /// once, which names the file in the confirmation — restoring the wrong one
  /// is the mistake worth spending a dialog on.
  final String? pendingRestorePath;

  /// What the last purge removed, for the screen to report in figures.
  final PurgeResult? purgeResult;

  final String? error;
  final String? message;

  const BackupState({
    this.databasePath,
    this.lastBackupPath,
    this.footprint,
    this.isSaving = false,
    this.isRestoring = false,
    this.isClearing = false,
    this.pendingRestorePath,
    this.purgeResult,
    this.error,
    this.message,
  });

  /// Any operation that has the database file open for rewriting.
  bool get isBusy => isSaving || isRestoring || isClearing;

  BackupState copyWith({
    String? databasePath,
    String? lastBackupPath,
    DataFootprint? footprint,
    bool? isSaving,
    bool? isRestoring,
    bool? isClearing,
    String? pendingRestorePath,
    PurgeResult? purgeResult,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) => BackupState(
    databasePath: databasePath ?? this.databasePath,
    lastBackupPath: lastBackupPath ?? this.lastBackupPath,
    footprint: footprint ?? this.footprint,
    isSaving: isSaving ?? this.isSaving,
    isRestoring: isRestoring ?? this.isRestoring,
    isClearing: isClearing ?? this.isClearing,
    // One-shot: the screen acts on the transition, and the next emit takes it
    // away so the dialog does not reopen on every rebuild.
    pendingRestorePath: pendingRestorePath,
    purgeResult: purgeResult,
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// The backup, the restore, and the two ways of deleting in bulk.
///
/// With no server, the file on this PC is the only copy of every attendance
/// record — which is what makes the backup the difference between a lost
/// machine costing an afternoon and costing the year's history, and what makes
/// every delete here answerable to it.
class BackupCubit extends Cubit<BackupState> {
  final BackupRepo _repo;

  BackupCubit(this._repo) : super(const BackupState());

  Future<void> load() async {
    emit(state.copyWith(databasePath: _repo.databasePath));
    await _refreshFootprint();
  }

  /// Never allowed to fail the screen: the figures are context for the buttons,
  /// and the backup button has to work on a database too damaged to count.
  Future<void> _refreshFootprint() async {
    try {
      emit(state.copyWith(footprint: await _repo.footprint()));
    } catch (_) {
      // Leaves the previous figures up rather than blanking the screen.
    }
  }

  // ------------------------------------------------------------- backing up

  Future<void> backupNow() async {
    if (state.isBusy) return;
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));

    try {
      final file = await _repo.backupNow();
      emit(
        state.copyWith(
          isSaving: false,
          lastBackupPath: file.path,
          message: LangKeys.backupDone,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.errorKey));
    } catch (_) {
      emit(state.copyWith(isSaving: false, error: LangKeys.backupFailed));
    }
  }

  // -------------------------------------------------------------- restoring

  /// Asks which backup to restore and hands it to the screen to confirm.
  /// Nothing is replaced by this.
  Future<void> chooseBackupToRestore({
    required String typeLabel,
    String? confirmLabel,
  }) async {
    if (state.isBusy) return;

    try {
      final path = await _repo.pickBackupFile(
        typeLabel: typeLabel,
        confirmLabel: confirmLabel,
      );
      // Closing the picker is an answer, not a failure.
      if (path == null) return;
      emit(state.copyWith(pendingRestorePath: path, clearError: true));
    } catch (_) {
      emit(state.copyWith(error: LangKeys.errorRestoreUnreadable));
    }
  }

  /// Replaces the live database with the confirmed backup.
  ///
  /// Everything on screen elsewhere in the app is reading the old data, and
  /// nothing here can reach in and refresh it — hence the message telling the
  /// admin to restart, rather than a quiet success they would act on.
  Future<void> restore(String path) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(isRestoring: true, clearError: true, clearMessage: true),
    );

    try {
      await _repo.restore(path);
      await _refreshFootprint();
      emit(
        state.copyWith(
          isRestoring: false,
          databasePath: _repo.databasePath,
          message: LangKeys.backupRestoreDone,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isRestoring: false, error: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(
          isRestoring: false,
          error: LangKeys.errorRestoreUnreadable,
        ),
      );
    }
  }

  // --------------------------------------------------------------- clearing

  /// Removes every record dated before [date].
  Future<void> clearBefore(String date) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(isClearing: true, clearError: true, clearMessage: true),
    );

    try {
      final result = await _repo.purgeBefore(date);
      await _refreshFootprint();
      emit(
        state.copyWith(
          isClearing: false,
          purgeResult: result,
          message: result.removedNothing
              ? LangKeys.dataClearNothing
              : LangKeys.dataClearDone,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isClearing: false, error: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isClearing: false, error: LangKeys.errorDataClearFailed),
      );
    }
  }

  /// Empties the staff list and every record hanging off it — after writing a
  /// backup, and only if that backup was written.
  ///
  /// The forced backup is the whole reason this is safe to offer. It is not a
  /// suggestion in the dialog that an admin can wave past: if the copy cannot
  /// be saved, nothing is deleted and the failure says so.
  Future<void> eraseAll() async {
    if (state.isBusy) return;
    emit(
      state.copyWith(isClearing: true, clearError: true, clearMessage: true),
    );

    final String backupPath;
    try {
      backupPath = (await _repo.backupNow()).path;
    } catch (_) {
      emit(
        state.copyWith(isClearing: false, error: LangKeys.errorBackupRequired),
      );
      return;
    }

    try {
      await _repo.eraseOperationalData();
      await _refreshFootprint();
      emit(
        state.copyWith(
          isClearing: false,
          lastBackupPath: backupPath,
          message: LangKeys.dataEraseDone,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isClearing: false, error: e.errorKey));
    } catch (_) {
      emit(
        state.copyWith(isClearing: false, error: LangKeys.errorDataClearFailed),
      );
    }
  }
}
