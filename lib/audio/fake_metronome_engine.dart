import 'dart:async';

import '../../domain/beat_event.dart';
import '../../domain/metronome_settings.dart';
import 'bar_renderer.dart';
import 'beat_tracker.dart';
import 'fakes.dart';
import 'metronome_engine.dart';

/// Test double: a perfect "audio clock" you advance by hand. Uses the real
/// [BarRenderer] and [BeatTracker], so beat timing logic is exercised.
class FakeMetronomeEngine implements MetronomeEngine {
  FakeMetronomeEngine({FakeClock? clock, this.pollMs = 8})
      : clock = clock ?? FakeClock();

  final FakeClock clock;
  final double pollMs;

  final _beats = StreamController<BeatEvent>.broadcast();
  MetronomeSettings? _settings;
  BeatTracker? _tracker;
  double _elapsedMs = 0;
  double _loopMs = 1;
  bool _running = false;

  /// Everything passed to start/updateSettings, for assertions.
  final List<MetronomeSettings> history = [];
  Object? failOnStart;

  MetronomeSettings? get settings => _settings;

  @override
  Stream<BeatEvent> get beats => _beats.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(MetronomeSettings settings) async {
    final failure = failOnStart;
    if (failure != null) throw failure;
    _settings = settings.validated();
    history.add(_settings!);
    _begin();
  }

  void _begin() {
    final s = _settings!;
    final bar = BarRenderer.render(s);
    _loopMs = bar.durationMs;
    _elapsedMs = 0;
    _tracker = BeatTracker(
      beatsPerBar: s.beatsPerBar,
      loopLengthMs: _loopMs,
      accentFirstBeat: s.accentFirstBeat,
    );
    _running = true;
    _poll();
  }

  @override
  Future<void> updateSettings(MetronomeSettings settings) async {
    final old = _settings;
    _settings = settings.validated();
    history.add(_settings!);
    if (_running && old != null && !old.sameClickPatternAs(_settings!)) _begin();
  }

  /// Advances time by [ms], polling like the real engine would.
  void advance(double ms) {
    var left = ms;
    while (left > 0) {
      final step = left < pollMs ? left : pollMs;
      clock.advance(step);
      _elapsedMs += step;
      left -= step;
      _poll();
    }
  }

  void _poll() {
    final tracker = _tracker;
    if (!_running || tracker == null) return;
    for (final e in tracker.update(
      positionMs: _elapsedMs % _loopMs,
      nowMs: clock.nowMs,
    )) {
      _beats.add(e);
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _tracker = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _beats.close();
  }
}
