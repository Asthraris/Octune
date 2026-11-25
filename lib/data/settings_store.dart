/// Tiny key-value store for settings. Reads are synchronous (the backing
/// store is loaded once at startup); writes are asynchronous.
abstract interface class SettingsStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;
  int writeCount = 0;

  @override
  String? read(String key) => data[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}
