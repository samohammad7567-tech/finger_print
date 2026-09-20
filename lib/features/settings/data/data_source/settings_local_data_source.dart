import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalDataSource {
  final SharedPreferences _prefs;

  SettingsLocalDataSource(this._prefs);

  bool getIsDark() => _prefs.getBool('is_dark') ?? true;
  Future<void> setIsDark(bool value) => _prefs.setBool('is_dark', value);

  bool getIsArabic() => _prefs.getBool('is_arabic') ?? false;
  Future<void> setIsArabic(bool value) => _prefs.setBool('is_arabic', value);

  bool getLateAlerts() => _prefs.getBool('late_alerts') ?? true;
  Future<void> setLateAlerts(bool value) =>
      _prefs.setBool('late_alerts', value);

  bool getMissingCheckoutAlerts() =>
      _prefs.getBool('missing_checkout_alerts') ?? true;
  Future<void> setMissingCheckoutAlerts(bool value) =>
      _prefs.setBool('missing_checkout_alerts', value);

  /// Where the last export was saved, so the save dialog opens there again
  /// rather than sending the admin back to Documents every month.
  String? getLastExportFolder() {
    final folder = _prefs.getString('last_export_folder');
    return folder == null || folder.isEmpty ? null : folder;
  }

  Future<void> setLastExportFolder(String value) =>
      _prefs.setString('last_export_folder', value);

  /// The last date the absence pass finished with, 'yyyy-MM-dd'.
  ///
  /// Null on a first run, which is what tells the pass to reach back over a
  /// bounded window instead of only looking at yesterday. Kept in preferences
  /// rather than the database because it is a fact about this installation's
  /// progress, not about the attendance it records.
  String? getClosedThrough() {
    final date = _prefs.getString('attendance_closed_through');
    return date == null || date.isEmpty ? null : date;
  }

  Future<void> setClosedThrough(String date) =>
      _prefs.setString('attendance_closed_through', date);
}
