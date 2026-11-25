import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_codec.dart';
import '../data/settings_store.dart';
import '../domain/detection_preset.dart';
import '../domain/detector_settings.dart';
import '../domain/note_name.dart';
import '../domain/ui_settings.dart';
import 'providers.dart';

class SettingsState {
  const SettingsState({required this.detector, required this.ui});

  final DetectorSettings detector;
  final UiSettings ui;

  /// The instrument preset matching the current range, or null (custom).
  DetectionPreset? get preset => DetectionPreset.matching(detector);

  SettingsState copyWith({DetectorSettings? detector, UiSettings? ui}) =>
      SettingsState(detector: detector ?? this.detector, ui: ui ?? this.ui);

  @override
  bool operator ==(Object other) =>
      other is SettingsState && other.detector == detector && other.ui == ui;

  @override
  int get hashCode => Object.hash(detector, ui);
}

/// Holds detector and UI settings, applies them live, and persists them.
///
/// Detector changes reach the DSP through [ListeningController], which
/// listens to this state. Writes are debounced (sliders produce many
/// changes); call [flush] to write immediately.
class SettingsController extends Notifier<SettingsState> {
  static const Duration saveDelay = Duration(milliseconds: 300);

  late SettingsStore _store;
  Timer? _saveTimer;

  // Latest values waiting to be written. Captured here so flush() never has
  // to read `state` (it also runs while the provider is being disposed).
  DetectorSettings? _pendingDetector;
  UiSettings? _pendingUi;

  @override
  SettingsState build() {
    _store = ref.read(settingsStoreProvider);
    ref.onDispose(() {
      _saveTimer?.cancel();
      unawaited(flush());
    });
    return SettingsState(
      detector: decodeDetector(_store.read(kDetectorSettingsKey)),
      ui: decodeUi(_store.read(kUiSettingsKey)),
    );
  }

  // -- detector ------------------------------------------------------------

  void setA4Hz(double hz) => _setDetector(state.detector.copyWith(a4Hz: hz));

  void setNoiseGate(double value) =>
      _setDetector(state.detector.copyWith(noiseGate: value));

  void setMinConfidence(double value) =>
      _setDetector(state.detector.copyWith(minConfidence: value));

  void setDetectionPreset(DetectionPreset preset) =>
      _setDetector(preset.applyTo(state.detector));

  void setFrequencyRange(double minHz, double maxHz) => _setDetector(
      state.detector.copyWith(minFrequencyHz: minHz, maxFrequencyHz: maxHz));

  /// Moves the gate threshold (dragging the dotted line). The DSP applies it
  /// at once; the equivalent 0..1 gate value is stored and returned.
  double setGateThresholdDb(double db) {
    final gate = ref.read(frameAnalyzerProvider).setGateThresholdDb(db);
    _setDetector(state.detector.copyWith(noiseGate: gate));
    return gate;
  }

  void _setDetector(DetectorSettings next) {
    final valid = next.validated();
    if (valid == state.detector) return;
    state = state.copyWith(detector: valid);
    _pendingDetector = valid;
    _scheduleSave();
  }

  // -- ui ------------------------------------------------------------------

  void setAccidentalPreference(AccidentalPreference value) =>
      _setUi(state.ui.copyWith(accidentalPreference: value));

  void setShowCents(bool value) => _setUi(state.ui.copyWith(showCents: value));

  void setKeepScreenAwake(bool value) =>
      _setUi(state.ui.copyWith(keepScreenAwake: value));

  void setReduceMotion(bool value) =>
      _setUi(state.ui.copyWith(reduceMotion: value));

  void _setUi(UiSettings next) {
    if (next == state.ui) return;
    state = state.copyWith(ui: next);
    _pendingUi = next;
    _scheduleSave();
  }

  // -- all -----------------------------------------------------------------

  void resetToDefaults() {
    state = const SettingsState(detector: DetectorSettings(), ui: UiSettings());
    _pendingDetector = const DetectorSettings();
    _pendingUi = const UiSettings();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(flush()));
  }

  /// Writes any pending changes now.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final writes = <Future<void>>[];
    final detector = _pendingDetector;
    final ui = _pendingUi;
    _pendingDetector = null;
    _pendingUi = null;
    if (detector != null) {
      writes.add(_store.write(kDetectorSettingsKey, encodeDetector(detector)));
    }
    if (ui != null) {
      writes.add(_store.write(kUiSettingsKey, encodeUi(ui)));
    }
    try {
      await Future.wait(writes);
    } catch (_) {
      // Settings simply will not persist; the app keeps working.
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
