import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_codec.dart';
import '../domain/beat_event.dart';
import '../domain/bpm_tap_calculator.dart';
import '../domain/metronome_settings.dart';
import 'providers.dart';

class MetronomeState {
  const MetronomeState({
    required this.running,
    required this.settings,
    this.lastBeat,
    this.errorMessage,
  });

  final bool running;
  final MetronomeSettings settings;

  /// Most recent beat announced by the engine (may be slightly in the future).
  final BeatEvent? lastBeat;
  final String? errorMessage;

  MetronomeState copyWith({
    bool? running,
    MetronomeSettings? settings,
    BeatEvent? lastBeat,
    bool clearBeat = false,
    String? errorMessage,
    bool clearError = false,
  }) =>
      MetronomeState(
        running: running ?? this.running,
        settings: settings ?? this.settings,
        lastBeat: clearBeat ? null : (lastBeat ?? this.lastBeat),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

/// Start/stop, BPM, tap tempo, time signature, accent, volume.
class MetronomeController extends Notifier<MetronomeState> {
  static const Duration saveDelay = Duration(milliseconds: 300);

  final BpmTapCalculator _tap = BpmTapCalculator();
  Timer? _saveTimer;
  MetronomeSettings? _pendingSave;
  bool _disposed = false;

  /// True from just before the engine starts until it stops. The engine
  /// announces beat 0 while start() is still running, i.e. before `running`
  /// becomes true, so beats cannot be gated on `state.running`.
  bool _acceptBeats = false;

  @override
  MetronomeState build() {
    _disposed = false;
    final engine = ref.read(metronomeEngineProvider);
    final store = ref.read(settingsStoreProvider);

    final beats = engine.beats.listen((beat) {
      if (!_disposed && _acceptBeats) state = state.copyWith(lastBeat: beat);
    });
    ref.onDispose(() {
      _disposed = true;
      beats.cancel();
      _saveTimer?.cancel();
      final pending = _pendingSave;
      if (pending != null) {
        unawaited(store.write(kMetronomeSettingsKey, encodeMetronome(pending)));
      }
      unawaited(engine.stop().catchError((Object _) {}));
    });

    return MetronomeState(
      running: false,
      settings: decodeMetronome(store.read(kMetronomeSettingsKey)),
    );
  }

  Future<void> toggle() => state.running ? stop() : start();

  Future<void> start() async {
    if (state.running) return;
    _acceptBeats = true;
    try {
      await ref.read(metronomeEngineProvider).start(state.settings);
      if (_disposed) return;
      state = state.copyWith(running: true, clearError: true);
    } catch (e) {
      _acceptBeats = false;
      if (_disposed) return;
      state = state.copyWith(running: false, errorMessage: 'Metronome failed to start: $e');
    }
  }

  Future<void> stop() async {
    if (!state.running) return;
    _acceptBeats = false;
    state = state.copyWith(running: false, clearBeat: true);
    try {
      await ref.read(metronomeEngineProvider).stop();
    } catch (_) {
      // Already stopped.
    }
  }

  // -- settings ------------------------------------------------------------

  Future<void> setBpm(int bpm) => _apply(state.settings.copyWith(bpm: bpm));

  Future<void> nudgeBpm(int delta) =>
      _apply(state.settings.copyWith(bpm: state.settings.bpm + delta));

  Future<void> setTimeSignature(int beatsPerBar, int beatUnit) => _apply(
      state.settings.copyWith(beatsPerBar: beatsPerBar, beatUnit: beatUnit));

  Future<void> setAccentFirstBeat(bool value) =>
      _apply(state.settings.copyWith(accentFirstBeat: value));

  Future<void> setSubdivision(int value) =>
      _apply(state.settings.copyWith(subdivision: value));

  Future<void> setVolume(double value) =>
      _apply(state.settings.copyWith(volume: value));

  /// Registers a tap. After two or more taps the BPM follows the taps.
  Future<void> tapTempo() async {
    final bpm = _tap.tap(ref.read(clockProvider).nowMs.round());
    if (bpm != null) await setBpm(bpm.round());
  }

  Future<void> _apply(MetronomeSettings next) async {
    final valid = next.validated();
    if (valid == state.settings) return;
    state = state.copyWith(settings: valid);
    _scheduleSave(valid);
    if (state.running) {
      try {
        await ref.read(metronomeEngineProvider).updateSettings(valid);
      } catch (e) {
        if (!_disposed) {
          state = state.copyWith(errorMessage: 'Metronome update failed: $e');
        }
      }
    }
  }

  void _scheduleSave(MetronomeSettings settings) {
    _pendingSave = settings;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Writes pending settings now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _pendingSave;
    _pendingSave = null;
    if (pending == null) return;
    try {
      await ref
          .read(settingsStoreProvider)
          .write(kMetronomeSettingsKey, encodeMetronome(pending));
    } catch (_) {
      // Will not persist; the metronome keeps working.
    }
  }
}

final metronomeProvider =
    NotifierProvider<MetronomeController, MetronomeState>(MetronomeController.new);
