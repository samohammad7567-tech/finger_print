import '../data_source/shifts_local_data_source.dart';
import '../models/shift_model.dart';
import '../models/shift_schedules.dart';

/// Thin delegation over the shifts table.
class ShiftsRepo {
  final ShiftsLocalDataSource _dataSource;

  ShiftsRepo(this._dataSource);

  Future<List<ShiftModel>> getShifts() => _dataSource.getShifts();

  /// The hours to judge people by, for a screen about to read a whole month.
  Future<ShiftSchedules> getSchedules() => _dataSource.getSchedules();

  Future<ShiftModel> createShift(ShiftModel shift) =>
      _dataSource.createShift(shift);

  Future<ShiftModel> updateShift(ShiftModel shift) =>
      _dataSource.updateShift(shift);

  Future<void> deleteShift(String id) => _dataSource.deleteShift(id);
}
