/// Whether the app is in the foreground. Emits false when it goes to the
/// background (the microphone should be released) and true when it returns.
abstract interface class AppLifecycleSource {
  Stream<bool> get foreground;
}
