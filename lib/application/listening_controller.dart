import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_input.dart';
import '../audio/permission_service.dart';
import '../domain/analysis_snapshot.dart';
import '../domain/note_change.dart';
import '../domain/recent_notes.dart';
import 'listening_session.dart';
import 'listening_state.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// The one-tap "listen" controller.
///
/// toggle(): idle -> check/ask microphone permission -> start; listening ->
/// stop. Handles denial, interruptions, errors, going to the background, and
/// keeps the screen awake while listening if the setting is on.
class ListeningController extends Notifier<ListeningState> {
  ListeningSession? _session;
  final StreamController<NoteChange> _noteChanges =
      StreamController<NoteChange>.broadcast();
  bool _starting = false;
  bool _disposed = false;
  bool _wakelockOn = false;

  /// Every change of the stable note (start, change, end), for recording.
  Stream<NoteChange> get noteChanges => _noteChanges.stream;

  @override
  ListeningState build() {
    _disposed = false;
    final analyzer = ref.read(frameAnalyzerProvider);
    final wakelock = ref.read(wakelockServiceProvider); // captured: no ref use in onDispose
    analyzer.updateSettings(ref.read(settingsProvider).detector);

    // Settings changes reach the DSP live, even while idle.
    ref.listen(settingsProvider.select((s) => s.detector), (_, next) {
      analyzer.updateSettings(next);
    });
    ref.listen(settingsProvider.select((s) => s.ui.keepScreenAwake), (_, __) {
      unawaited(_syncWakelock());
    });

    // Release the microphone when the app goes to the background.
    final lifecycle = ref.read(appLifecycleSourceProvider).foreground.listen((fg) {
      if (!fg && state.isActive) unawaited(stop());
    });

    ref.onDispose(() {
      _disposed = true;
      lifecycle.cancel();
      final session = _session;
      _session = null;
      if (session != null) unawaited(session.stop().catchError((Object _) {}));
      _noteChanges.close();
      if (_wakelockOn) {
        _wakelockOn = false;
        unawaited(wakelock.setEnabled(false).catchError((Object _) {}));
      }
    });
    return ListeningState.initial();
  }

  /// One tap: start when stopped, stop when listening.
  Future<void> toggle() async {
    switch (state.status) {
      case ListeningStatus.idle:
      case ListeningStatus.permissionDenied:
      case ListeningStatus.permissionPermanentlyDenied:
      case ListeningStatus.error:
        await start();
      case ListeningStatus.listening:
      case ListeningStatus.interrupted:
        await stop();
      case ListeningStatus.requestingPermission:
        break;
    }
  }

  Future<void> start() async {
    if (_starting || _session != null || _disposed) return;
    _starting = true;
    _update(status: ListeningStatus.requestingPermission, clearError: true);
    try {
      final permission = ref.read(permissionServiceProvider);
      var status = await permission.status();
      if (status == MicPermissionStatus.denied) {
        status = await permission.request();
      }
      if (_disposed) return;
      switch (status) {
        case MicPermissionStatus.granted:
          break;
        case MicPermissionStatus.denied:
          _update(status: ListeningStatus.permissionDenied);
          return;
        case MicPermissionStatus.permanentlyDenied:
          _update(status: ListeningStatus.permissionPermanentlyDenied);
          return;
        case MicPermissionStatus.restricted:
          _update(
            status: ListeningStatus.permissionPermanentlyDenied,
            errorMessage: 'Microphone access is restricted on this device.',
          );
          return;
      }

      final session = ListeningSession(
        input: ref.read(audioInputProvider),
        analyzer: ref.read(frameAnalyzerProvider),
        onSnapshot: _onSnapshot,
        onNoteChange: _onNoteChange,
        onInputEvent: _onInputEvent,
      );
      _session = session;
      await session.start();
      if (_disposed) {
        await session.stop();
        return;
      }
      _update(status: ListeningStatus.listening);
      await _syncWakelock();
    } catch (e) {
      _session = null;
      _update(status: ListeningStatus.error, errorMessage: _describe(e));
      await _syncWakelock();
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    _session = null;
    try {
      await session.stop();
    } catch (_) {
      // The input was already gone; the session is over either way.
    }
    if (_disposed) return;
    _update(status: ListeningStatus.idle, clearError: true);
    await _syncWakelock();
  }

  /// Opens system settings (for "permanently denied").
  Future<void> openPermissionSettings() =>
      ref.read(permissionServiceProvider).openSettings();

  // -- session callbacks ---------------------------------------------------

  void _onSnapshot(AnalysisSnapshot snapshot, RecentNotes recent) {
    if (_disposed) return;
    // Keep the interrupted/idle status; only data changes here.
    state = state.copyWith(snapshot: snapshot, recent: recent);
  }

  void _onNoteChange(NoteChange change) {
    if (!_disposed && !_noteChanges.isClosed) _noteChanges.add(change);
  }

  void _onInputEvent(AudioInputEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case AudioInputEventType.interrupted:
        if (state.status == ListeningStatus.listening) {
          _update(status: ListeningStatus.interrupted, snapshot: AnalysisSnapshot.empty());
        }
      case AudioInputEventType.resumed:
        if (state.status == ListeningStatus.interrupted) {
          ref.read(frameAnalyzerProvider).reset();
          _update(status: ListeningStatus.listening);
        }
      case AudioInputEventType.deviceChanged:
        // A different microphone has different noise: re-learn the floor.
        ref.read(frameAnalyzerProvider).reset();
      case AudioInputEventType.error:
        unawaited(_failWith(event.message ?? 'Audio input failed.'));
    }
  }

  Future<void> _failWith(String message) async {
    await stop();
    if (!_disposed) _update(status: ListeningStatus.error, errorMessage: message);
  }

  // -- helpers -------------------------------------------------------------

  void _update({
    ListeningStatus? status,
    AnalysisSnapshot? snapshot,
    String? errorMessage,
    bool clearError = false,
  }) {
    if (_disposed) return;
    state = state.copyWith(
      status: status,
      snapshot: snapshot,
      errorMessage: errorMessage,
      clearError: clearError,
    );
  }

  Future<void> _syncWakelock() async {
    if (_disposed) return;
    final want = ref.read(settingsProvider).ui.keepScreenAwake && state.isActive;
    if (want == _wakelockOn) return;
    _wakelockOn = want;
    try {
      await ref.read(wakelockServiceProvider).setEnabled(want);
    } catch (_) {
      // Not available on this platform; harmless.
    }
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}

final listeningProvider =
    NotifierProvider<ListeningController, ListeningState>(ListeningController.new);

/// Stable-note changes for the recording feature (Phase 2).
final noteChangesProvider = Provider<Stream<NoteChange>>(
    (ref) => ref.watch(listeningProvider.notifier).noteChanges);
