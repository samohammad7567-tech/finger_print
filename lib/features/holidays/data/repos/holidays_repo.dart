import '../data_source/holidays_local_data_source.dart';
import '../models/holiday_model.dart';
import '../models/work_calendar.dart';

/// Thin delegation over the holidays table.
class HolidaysRepo {
  final HolidaysLocalDataSource _dataSource;

  HolidaysRepo(this._dataSource);

  Future<List<HolidayModel>> getHolidays() => _dataSource.getHolidays();

  /// The calendar a screen judges a month of dates against.
  Future<WorkCalendar> getCalendar() => _dataSource.getCalendar();

  Future<HolidayModel> createHoliday(HolidayModel holiday) =>
      _dataSource.createHoliday(holiday);

  Future<HolidayModel> updateHoliday(HolidayModel holiday) =>
      _dataSource.updateHoliday(holiday);

  Future<void> deleteHoliday(String id) => _dataSource.deleteHoliday(id);
}
