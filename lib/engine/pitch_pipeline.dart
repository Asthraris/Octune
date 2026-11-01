import 'dart:typed_data';

import '../domain/analysis_snapshot.dart';
import '../domain/detector_settings.dart';
import '../domain/note_event.dart';
import '../domain/note_math.dart';
import 'amplitude_meter.dart';
import 'dc_removal.dart';
import 'note_stabilizer.dart';
import 'noise_gate.dart';
import 'pitch_class_energy.dart';
import 'pitch_detector.dart';
import 'spectrum_analyzer.dart';
import 'yin_pitch_detector.dart';

/// Frame in, [AnalysisSnapshot] out:
/// DC removal -> level -> noise gate -> (spectrum) -> pitch detector ->
/// confidence filter -> nearest note -> stabilizer -> snapshot.
///
/// When the gate is closed or confidence is low, no note is produced. The
/// pipeline never guesses.
///
/// Expects fixed-size frames (default 2048) at a steady hop. Timestamps are
/// in milliseconds from any fixed origin.
class PitchPipeline {
  PitchPipeline({
    required PitchDetector detector,
    required SpectrumAnalyzer spectrumAnalyzer,
    AmplitudeMeter? meter,
    NoiseGate? gate,
    NoteStabilizer? stabilizer,
    PitchClassEnergy? pitchClasses,
    DetectorSettings settings = const DetectorSettings(),
  })  : _detector = detector,
        _spectrum = spectrumAnalyzer,
        _meter = meter ?? AmplitudeMeter(),
        _gate = gate ?? NoiseGate(noiseGate: settings.noiseGate),
        _stabilizer = stabilizer ?? NoteStabilizer(),
        _pitchClasses = pitchClasses ?? PitchClassEnergy(),
        _settings = settings.validated() {
    _detector.setFrequencyRange(
        _settings.minFrequencyHz, _settings.maxFrequencyHz);
    _gate.configure(noiseGate: _settings.noiseGate);
  }

  /// Default wiring: YIN + 2048 frames.
  factory PitchPipeline.standard({
    DetectorSettings settings = const DetectorSettings(),
    int frameSize = 2048,
  }) {
    final s = settings.validated();
    return PitchPipeline(
      detector: YinPitchDetector(
        minHz: s.minFrequencyHz,
        maxHz: s.maxFrequencyHz,
        windowSize: frameSize,
      ),
      spectrumAnalyzer: SpectrumAnalyzer(fftSize: frameSize),
      settings: s,
    );
  }

  final PitchDetector _detector;
  final SpectrumAnalyzer _spectrum;
  final AmplitudeMeter _meter;
  final NoiseGate _gate;
  final NoteStabilizer _stabilizer;
  final PitchClassEnergy _pitchClasses;

  DetectorSettings _settings;
  Float32List _work = Float32List(0);
  int? _lastTimestampMs;
  bool _lastPitched = true;
  double _lastClarity = 0;

  DetectorSettings get settings => _settings;
  double get gateThresholdDb => _gate.thresholdDb;
  double get noiseFloorDb => _gate.noiseFloorDb;

  /// Applies new settings immediately (A4, gate, confidence, range).
  void updateSettings(DetectorSettings settings) {
    _settings = settings.validated();
    _gate.configure(noiseGate: _settings.noiseGate);
    _detector.setFrequencyRange(
        _settings.minFrequencyHz, _settings.maxFrequencyHz);
  }

  /// Moves the gate threshold line (UI drag). Returns, and stores in the
  /// settings, the equivalent 0..1 noiseGate value.
  double setGateThresholdDb(double db) {
    final g = _gate.setThresholdDb(db);
    _settings = _settings.copyWith(noiseGate: g);
    return g;
  }

  void reset() {
    _gate.reset();
    _stabilizer.reset();
    _pitchClasses.reset();
    _lastTimestampMs = null;
    _lastPitched = true;
    _lastClarity = 0;
  }

  AnalysisSnapshot process(Float32List frame, int sampleRate, int timestampMs) {
    if (_work.length != frame.length) _work = Float32List(frame.length);
    removeDcOffset(frame, _work);

    final level = _meter.measure(_work);
    final dtMs = _deltaMs(timestampMs, frame.length, sampleRate);
    final gateOpen = _gate.process(level.db, dtMs, pitched: _lastPitched);

    // Spectrum is always computed so the signal panel can show noise too.
    final spectrum = _spectrum.analyze(
      _work,
      sampleRate,
      noiseFloorDb: _gate.noiseFloorDb,
    );

    PitchAnalysis analysis;
    NoteReading? reading;
    PitchEstimate? accepted;
    if (gateOpen) {
      analysis = _detector.analyze(_work, sampleRate);
      final estimate = analysis.estimate;
      if (estimate != null && estimate.clarity >= _settings.minConfidence) {
        accepted = estimate;
        reading = nearestNote(estimate.frequencyHz, a4: _settings.a4Hz);
        _lastClarity = estimate.clarity;
      }
    } else {
      analysis = _detector.emptyAnalysis(sampleRate);
    }
    _lastPitched = reading != null;

    final stable = _stabilizer.process(reading);
    NoteEvent? event;
    if (stable != null) {
      event = NoteEvent(
        tMs: timestampMs,
        noteName: stable.noteName,
        octave: stable.octave,
        cents: stable.centsOffset,
        amp: level.linear,
        conf: _lastClarity,
      );
    }

    final classes = _pitchClasses.update(
      gateOpen ? spectrum.peaks : const [],
      dtMs,
      a4Hz: _settings.a4Hz,
      noiseFloorDb: _gate.noiseFloorDb,
    );

    return AnalysisSnapshot(
      timestampMs: timestampMs,
      stableNote: event,
      detectedHz: accepted?.frequencyHz,
      confidence: accepted?.clarity ?? 0,
      amplitudeLinear: level.linear,
      amplitudeDb: level.db,
      gateOpen: gateOpen,
      gateThresholdDb: _gate.thresholdDb,
      noiseFloorDb: _gate.noiseFloorDb,
      salienceBySemitone: analysis.salienceBySemitone,
      salienceLowestMidi: analysis.salienceLowestMidi,
      pitchClassEnergy: classes,
      spectrum: spectrum.view,
    );
  }

  double _deltaMs(int timestampMs, int frameLength, int sampleRate) {
    final hopMs = frameLength / 2 * 1000 / sampleRate;
    final last = _lastTimestampMs;
    _lastTimestampMs = timestampMs;
    if (last == null) return hopMs;
    final dt = (timestampMs - last).toDouble();
    return (dt <= 0 || dt > 500) ? hopMs : dt;
  }
}
