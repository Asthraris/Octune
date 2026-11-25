import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

/// [SettingsStore] on `shared_preferences`. Create it once at startup after
/// `SharedPreferences.getInstance()` so reads can stay synchronous.
class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
