enum MicPermissionStatus { granted, denied, permanentlyDenied, restricted }

abstract interface class PermissionService {
  /// Current state without prompting.
  Future<MicPermissionStatus> status();

  /// Prompts the user if the platform allows it, then returns the new state.
  Future<MicPermissionStatus> request();

  /// Opens the system settings page for this app.
  Future<void> openSettings();
}
