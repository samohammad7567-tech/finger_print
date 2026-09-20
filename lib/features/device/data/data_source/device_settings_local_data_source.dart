import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_settings_model.dart';

/// Where the terminal's address and sync preferences are kept.
///
/// Preferences rather than the database: these describe this PC's link to the
/// hardware, not attendance data, so they should not travel in a restored
/// backup that might come from a machine pointed at a different terminal.
class DeviceSettingsLocalDataSource {
  static const _ip = 'zk_ip';
  static const _port = 'zk_port';
  static const _commKey = 'zk_comm_key';
  static const _useTcp = 'zk_use_tcp';
  static const _skipPing = 'zk_skip_ping';
  static const _autoSyncMinutes = 'zk_auto_sync_minutes';
  static const _debounceSeconds = 'zk_debounce_seconds';
  static const _importEmployees = 'zk_import_employees';
  static const _liveSync = 'zk_live_sync';

  final SharedPreferences _prefs;

  DeviceSettingsLocalDataSource(this._prefs);

  DeviceSettingsModel read() {
    const defaults = DeviceSettingsModel();
    return DeviceSettingsModel(
      ip: _prefs.getString(_ip) ?? defaults.ip,
      port: _prefs.getInt(_port) ?? defaults.port,
      commKey: _prefs.getString(_commKey) ?? defaults.commKey,
      useTcp: _prefs.getBool(_useTcp) ?? defaults.useTcp,
      skipPing: _prefs.getBool(_skipPing) ?? defaults.skipPing,
      autoSyncMinutes:
          _prefs.getInt(_autoSyncMinutes) ?? defaults.autoSyncMinutes,
      debounceSeconds:
          _prefs.getInt(_debounceSeconds) ?? defaults.debounceSeconds,
      importEmployees:
          _prefs.getBool(_importEmployees) ?? defaults.importEmployees,
      liveSync: _prefs.getBool(_liveSync) ?? defaults.liveSync,
    );
  }

  Future<void> write(DeviceSettingsModel settings) async {
    await _prefs.setString(_ip, settings.ip.trim());
    await _prefs.setInt(_port, settings.port);
    await _prefs.setString(_commKey, settings.commKey);
    await _prefs.setBool(_useTcp, settings.useTcp);
    await _prefs.setBool(_skipPing, settings.skipPing);
    await _prefs.setInt(_autoSyncMinutes, settings.autoSyncMinutes);
    await _prefs.setInt(_debounceSeconds, settings.debounceSeconds);
    await _prefs.setBool(_importEmployees, settings.importEmployees);
    await _prefs.setBool(_liveSync, settings.liveSync);
  }
}
