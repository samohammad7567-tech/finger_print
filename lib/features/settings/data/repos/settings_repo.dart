import '../../../../core/utils/work_schedule.dart';
import '../data_source/settings_local_data_source.dart';
import '../data_source/work_schedule_local_data_source.dart';

class SettingsRepo {
  final SettingsLocalDataSource _dataSource;
  final WorkScheduleLocalDataSource _schedule;

  SettingsRepo(this._dataSource, this._schedule);

  /// The company's working hours. Read straight through, so a screen opened
  /// after the admin changed them never shows the old ones.
  WorkSchedule getWorkSchedule() => _schedule.read();

  Future<void> setWorkSchedule(WorkSchedule schedule) =>
      _schedule.write(schedule);

  bool getIsDark() => _dataSource.getIsDark();
  Future<void> setIsDark(bool value) => _dataSource.setIsDark(value);

  bool getIsArabic() => _dataSource.getIsArabic();
  Future<void> setIsArabic(bool value) => _dataSource.setIsArabic(value);

  bool getLateAlerts() => _dataSource.getLateAlerts();
  Future<void> setLateAlerts(bool value) => _dataSource.setLateAlerts(value);

  bool getMissingCheckoutAlerts() => _dataSource.getMissingCheckoutAlerts();
  Future<void> setMissingCheckoutAlerts(bool value) =>
      _dataSource.setMissingCheckoutAlerts(value);

  String? getLastExportFolder() => _dataSource.getLastExportFolder();
  Future<void> setLastExportFolder(String value) =>
      _dataSource.setLastExportFolder(value);
}
