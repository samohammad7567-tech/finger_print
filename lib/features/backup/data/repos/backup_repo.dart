import 'dart:io';

import '../data_source/backup_data_source.dart';
import '../models/data_maintenance_models.dart';

/// Thin delegation over the one data source that owns the database file.
class BackupRepo {
  final BackupDataSource _dataSource;

  BackupRepo(this._dataSource);

  String get databasePath => _dataSource.databasePath;

  Future<File> backupNow() => _dataSource.backupNow();

  Future<String?> pickBackupFile({
    required String typeLabel,
    String? confirmLabel,
  }) => _dataSource.pickBackupFile(
    typeLabel: typeLabel,
    confirmLabel: confirmLabel,
  );

  Future<void> restore(String path) => _dataSource.restore(path);

  Future<DataFootprint> footprint() => _dataSource.footprint();

  Future<PurgeResult> purgeBefore(String date) =>
      _dataSource.purgeBefore(date);

  Future<void> eraseOperationalData() => _dataSource.eraseOperationalData();
}
