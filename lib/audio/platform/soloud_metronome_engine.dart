import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../domain/beat_event.dart';
import '../../domain/metronome_settings.dart';
import '../bar_renderer.dart';
import '../beat_tracker.dart';
import '../metronome_engine.dart';
import '../wav_encoder.dart';

/// Metronome on `flutter_soloud`.
///
/// One bar of clicks is rendered to a WAV in memory and looped by SoLoud's
/// native audio thread, so timing is sample-accurate and cannot be disturbed
/// by Dart timers, UI frames or garbage collection. The Dart side only
/// POLLS the loop position (every [pollInterval]) to announce beats to the
/// UI; late polling delays an announcement but never moves a click.
///
/// Changing BPM, bar length, accent or subdivision swaps in a new bar from
/// beat 0. Volume changes are applied live.
///
/// Tuning: the SoLoud buffer size sets output latency. This engine uses the
/// plugin's defaults; the UI's visual-latency compensation absorbs the rest.
class SoloudMetronomeEngine implements MetronomeEngine {
  SoloudMetronomeEngine({
    SoLoud? soloud,
    MonotonicClock? clock,
    this.sampleRate = 44100,
    this.pollInterval = const Duration(milliseconds: 8),
  })  : _soloud = soloud ?? SoLoud.instance,
        _clock = clock ?? SystemMonotonicClock();

  final SoLoud _soloud;
  final MonotonicClock _clock;
  final int sampleRate;
  final Duration pollInterval;

  final _beats = StreamController<BeatEvent>.broadcast();
  Future<void> _queue = Future<void>.value();
  Timer? _timer;
  AudioSource? _source;
  SoundHandle? _handle;
  BeatTracker? _tracker;
  MetronomeSettings? _settings;
  bool _running = false;
  int _generation = 0;

  @override
  Stream<BeatEvent> get beats => _beats.stream;

  @override
  bool get isRunning => _running;

  /// Runs [action] after every earlier call has finished.
  Future<void> _serialize(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> start(MetronomeSettings settings) => _serialize(() async {
        await _halt();
        _settings = settings.validated();
        if (!_soloud.isInitialized) {
          await _soloud.init(sampleRate: sampleRate);
        }
        await _loadAndPlay();
        _running = true;
        _timer = Timer.periodic(pollInterval, (_) => _poll());
        _poll();
      });

  Future<void> _loadAndPlay() async {
    final settings = _settings!;
    final bar = BarRenderer.render(settings, sampleRate: sampleRate);
    final wav = WavEncoder.pcm16Mono(bar.samples, sampleRate);
    final source =
        await _soloud.loadMem('octune_metronome_${_generation++}.wav', wav);
    _source = source;
    _tracker = BeatTracker(
      beatsPerBar: settings.beatsPerBar,
      loopLengthMs: bar.durationMs,
      accentFirstBeat: settings.accentFirstBeat,
    );
    _handle = _soloud.play(source, volume: settings.volume, looping: true);
  }

  void _poll() {
    final handle = _handle;
    final tracker = _tracker;
    if (!_running || handle == null || tracker == null) return;
    double positionMs;
    try {
      positionMs = _soloud.getPosition(handle).inMicroseconds / 1000.0;
    } catch (_) {
      return; // engine busy or shutting down; try again next tick
    }
    for (final event in tracker.update(positionMs: positionMs, nowMs: _clock.nowMs)) {
      if (!_beats.isClosed) _beats.add(event);
    }
  }

  @override
  Future<void> updateSettings(MetronomeSettings settings) => _serialize(() async {
        final old = _settings;
        final next = settings.validated();
        _settings = next;
        if (!_running || old == null) return;
        if (old.sameClickPatternAs(next)) {
          final handle = _handle;
          if (handle != null && old.volume != next.volume) {
            _soloud.setVolume(handle, next.volume);
          }
          return;
        }
        await _releasePlayback();
        await _loadAndPlay();
      });

  Future<void> _releasePlayback() async {
    final handle = _handle;
    final source = _source;
    _handle = null;
    _source = null;
    _tracker = null;
    if (handle != null) await _soloud.stop(handle);
    if (source != null) await _soloud.disposeSource(source);
  }

  Future<void> _halt() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    await _releasePlayback();
  }

  @override
  Future<void> stop() => _serialize(_halt);

  @override
  Future<void> dispose() async {
    await stop();
    await _beats.close();
  }
}
