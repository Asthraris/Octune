/// Which end of the pendulum's swing a beat lands on. Alternates every beat.
enum SwingSide { left, right }

/// One metronome beat, announced slightly before it sounds so the UI can
/// animate toward it.
class BeatEvent {
  const BeatEvent({
    required this.beatIndex,
    required this.beatInBar,
    required this.isAccent,
    required this.side,
    required this.scheduledAtMonotonicMs,
    this.outputLatencyMs,
  });

  /// Running count since the metronome started (0, 1, 2, ...).
  final int beatIndex;

  /// 0-based position inside the bar.
  final int beatInBar;
  final bool isAccent;
  final SwingSide side;

  /// When the beat sounds, in milliseconds on the engine's monotonic clock
  /// ([MonotonicClock]). May be slightly in the future when emitted.
  final double scheduledAtMonotonicMs;

  /// Device output latency if the engine knows it (usually null).
  final double? outputLatencyMs;

  @override
  String toString() =>
      'BeatEvent(#$beatIndex bar-beat $beatInBar${isAccent ? ' accent' : ''}, '
      '${side.name}, at ${scheduledAtMonotonicMs.toStringAsFixed(1)} ms)';
}

/// Millisecond clock that never goes backwards. Injected so tests can drive
/// time by hand.
abstract interface class MonotonicClock {
  double get nowMs;
}

/// Real clock based on [Stopwatch].
class SystemMonotonicClock implements MonotonicClock {
  SystemMonotonicClock() {
    _watch.start();
  }

  final Stopwatch _watch = Stopwatch();

  @override
  double get nowMs => _watch.elapsedMicroseconds / 1000;
}
