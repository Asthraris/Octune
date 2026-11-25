import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../permission_service.dart';

/// Microphone permission via `permission_handler` (Android, iOS).
/// Distinguishes "denied" from "permanently denied", so the UI can offer
/// "Open settings".
class PermissionHandlerService implements PermissionService {
  @override
  Future<MicPermissionStatus> status() async =>
      _map(await Permission.microphone.status);

  @override
  Future<MicPermissionStatus> request() async =>
      _map(await Permission.microphone.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  static MicPermissionStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return MicPermissionStatus.granted;
    }
    if (s.isPermanentlyDenied) return MicPermissionStatus.permanentlyDenied;
    if (s.isRestricted) return MicPermissionStatus.restricted;
    return MicPermissionStatus.denied;
  }
}

/// Permission via the recorder itself (macOS, Windows, Linux). It cannot tell
/// "denied" from "permanently denied" and cannot open system settings.
class RecordPermissionService implements PermissionService {
  RecordPermissionService(this._recorder);

  final AudioRecorder _recorder;

  @override
  Future<MicPermissionStatus> status() async =>
      await _recorder.hasPermission(request: false)
          ? MicPermissionStatus.granted
          : MicPermissionStatus.denied;

  @override
  Future<MicPermissionStatus> request() async =>
      await _recorder.hasPermission()
          ? MicPermissionStatus.granted
          : MicPermissionStatus.denied;

  @override
  Future<void> openSettings() async {}
}

/// Picks the best implementation for the current platform.
PermissionService createPlatformPermissionService(AudioRecorder recorder) =>
    (Platform.isAndroid || Platform.isIOS)
        ? PermissionHandlerService()
        : RecordPermissionService(recorder);
