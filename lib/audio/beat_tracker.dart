import 'dart:math' as math;

import '../../domain/beat_event.dart';

/// Turns the playback position of a looping click bar into [BeatEvent]s that
/// are announced up to [lookaheadMs] before they sound.
///
/// Pure logic, no audio: feed it the player's position and the current clock.
///
/// * The position may wrap at the end of each loop, or keep counting; both
///   work (a drop of more than half a loop counts as a wrap).
/// * Players report position in coarse steps. Between steps the audio time
///   is extrapolated from the clock, and if the position stops advancing
///   entirely the tracker keeps time on the clock alone.
/// * Beat times always come from the audio position, so a late UI frame
///   delays an event but never shifts its scheduled time.
class BeatTracker {
  BeatTracker({
    required this.beatsPerBar,
    required this.loopLengthMs,
    this.accentFirstBeat = true,
    this.lookaheadMs = 120,
  }) : assert(beatsPerBar > 0 && loopLengthMs > 0);

  final int beatsPerBar;
  final double loopLengthMs;
  final bool accentFirstBeat;
  final double lookaheadMs;

  double get beatMs => loopLengthMs / beatsPerBar;

  bool _started = false;
  double _base = 0; // whole loops completed before the current position
  double _lastRaw = 0;
  double _anchorAudioMs = 0;
  double _anchorNowMs = 0;
  double _lastAudioNow = 0;
  int _nextBeat = 0;

  /// Index of the next beat that has not been announced yet.
  int get nextBeatIndex => _nextBeat;

  /// Returns the beats that became due. [positionMs] is the player's
  /// position inside the loop; [nowMs] is the current monotonic time.
  List<BeatEvent> update({required double positionMs, required double nowMs}) {
    if (!_started) {
      _started = true;
      _lastRaw = positionMs;
      _anchorAudioMs = positionMs;
      _anchorNowMs = nowMs;
      _lastAudioNow = positionMs;
    } else {
      if (positionMs < _lastRaw - loopLengthMs / 2) _base += loopLengthMs;
      if (positionMs != _lastRaw) {
        _lastRaw = positionMs;
        _anchorAudioMs = _base + positionMs;
        _anchorNowMs = nowMs;
      }
    }
    final audioNow =
        math.max(_lastAudioNow, _anchorAudioMs + (nowMs - _anchorNowMs));
    _lastAudioNow = audioNow;

    final events = <BeatEvent>[];
    while (_nextBeat * beatMs - audioNow <= lookaheadMs) {
      final n = _nextBeat;
      final inBar = n % beatsPerBar;
      events.add(BeatEvent(
        beatIndex: n,
        beatInBar: inBar,
        isAccent: accentFirstBeat && inBar == 0,
        side: n.isEven ? SwingSide.left : SwingSide.right,
        scheduledAtMonotonicMs: nowMs + (n * beatMs - audioNow),
      ));
      _nextBeat++;
    }
    return events;
  }
}
