/// Keeps the screen on while listening.
abstract interface class WakelockService {
  Future<void> setEnabled(bool value);
}
