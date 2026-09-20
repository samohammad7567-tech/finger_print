import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/localization/lang_keys.dart';

class BackupState {
  /// Where the live database file sits, shown so an admin can find it.
  final String? databasePath;

  /// Full path of the copy written by the last successful backup.
  final String? lastBackupPath;

  final bool isSaving;
  final String? error;
  final String? message;

  const BackupState({
    this.databasePath,
    this.lastBackupPath,
    this.isSaving = false,
    this.error,
    this.message,
  });

  BackupState copyWith({
    String? databasePath,
    String? lastBackupPath,
    bool? isSaving,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) => BackupState(
    databasePath: databasePath ?? this.databasePath,
    lastBackupPath: lastBackupPath ?? this.lastBackupPath,
    isSaving: isSaving ?? this.isSaving,
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// Writes a copy of the database somewhere an admin can get at it.
///
/// With no server, the file on this PC is the only copy of every attendance
/// record, so this is the difference between a lost machine costing an
/// afternoon and costing the year's history.
class BackupCubit extends Cubit<BackupState> {
  final AppDatabase _database;

  BackupCubit(this._database) : super(const BackupState());

  void load() => emit(state.copyWith(databasePath: _database.path));

  Future<void> backupNow() async {
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true, clearError: true, clearMessage: true));

    try {
      final documents = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(documents.path, 'GuardSync Backups'));
      await folder.create(recursive: true);

      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final destination = p.join(folder.path, 'guardsync-$stamp.db');

      final file = await _database.backupTo(destination);

      emit(
        state.copyWith(
          isSaving: false,
          lastBackupPath: file.path,
          message: LangKeys.backupDone,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isSaving: false, error: LangKeys.backupFailed));
    }
  }
}
