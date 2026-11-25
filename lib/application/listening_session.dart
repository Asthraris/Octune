import 'dart:async';

import '../audio/audio_input.dart';
import '../domain/analysis_snapshot.dart';
import '../domain/frame_analyzer.dart';
import '../domain/note_change.dart';
import '../domain/recent_notes.dart';

/// One run of "microphone -> analysis -> UI updates". Plain Dart: no
/// Riverpod, no Flutter, so it is fully unit-testable and reusable (later by
/// recording).
///
/// * Every frame is analysed, but snapshots are published at most
///   [maxPublishHz] times per second, except that a change of note or of the
///   gate state is published immediately.
/// * [onNoteChange] fires only when the stable note changes (including to
///   "no note"), carrying the exact time.
class ListeningSession {
  ListeningSession({
    required this.input,
    required this.analyzer,
    required this.onSnapshot,
    required this.onNoteChange,
    required this.onInputEvent,
    this.maxPublishHz = 30,
    RecentNotes? recent,
  })  : _recent = recent ?? RecentNotes.empty(),
        _minIntervalMs = 1000 / maxPublishHz * 0.9;

  final AudioInput input;
  final FrameAnalyzer analyzer;
  final void Function(AnalysisSnapshot snapshot, RecentNotes recent) onSnapshot;
  final void Function(NoteChange change) onNoteChange;
  final void Function(AudioInputEvent event) onInputEvent;
  final int maxPublishHz;
  final double _minIntervalMs;

  StreamSubscription<AudioFrameChunk>? _frameSub;
  StreamSubscription<AudioInputEvent>? _eventSub;
  RecentNotes _recent;
  int? _currentMidi;
  bool _lastGateOpen = false;
  int? _lastPublishMs;
  int _lastFrameMs = 0;
  bool _active = false;

  /// Frames analysed so far (published or not).
  int framesProcessed = 0;

  /// Snapshots published so far.
  int snapshotsPublished = 0;

  RecentNotes get recent => _recent;
  bool get isActive => _active;

  /// Subscribes first, then starts the input, so no frame is missed.
  /// Throws if the input cannot start.
  Future<void> start() async {
    if (_active) return;
    _active = true;
    _frameSub = input.frames.listen(_onFrame);
    _eventSub = input.events.listen(onInputEvent);
    try {
      await input.start();
    } catch (_) {
      _active = false;
      await _cancelSubscriptions();
      rethrow;
    }
  }

  void _onFrame(AudioFrameChunk chunk) {
    if (!_active) return;
    final snapshot =
        analyzer.process(chunk.samples, chunk.sampleRate, chunk.timestampMs);
    framesProcessed++;
    _lastFrameMs = chunk.timestampMs;

    final midi = snapshot.stableNote?.midiNumber;
    final noteChanged = midi != _currentMidi;
    if (noteChanged) {
      _currentMidi = midi;
      _recent = _recent.update(midi);
      onNoteChange(NoteChange(chunk.timestampMs, snapshot.stableNote));
    }
    final gateChanged = snapshot.gateOpen != _lastGateOpen;
    _lastGateOpen = snapshot.gateOpen;
    final last = _lastPublishMs;
    final due = last == null || chunk.timestampMs - last >= _minIntervalMs;
    if (noteChanged || gateChanged || due) {
      _lastPublishMs = chunk.timestampMs;
      snapshotsPublished++;
      onSnapshot(snapshot, _recent);
    }
  }

  /// Stops the input and publishes a final empty snapshot. Safe to call twice.
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    await _cancelSubscriptions();
    try {
      await input.stop();
    } finally {
      analyzer.reset();
      if (_currentMidi != null) {
        _currentMidi = null;
        _recent = _recent.update(null);
        onNoteChange(NoteChange(_lastFrameMs, null));
      }
      onSnapshot(AnalysisSnapshot.empty(), _recent);
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _frameSub?.cancel();
    await _eventSub?.cancel();
    _frameSub = null;
    _eventSub = null;
  }
}
