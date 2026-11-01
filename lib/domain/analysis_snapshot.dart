import 'dart:typed_data';

import 'note_event.dart';
import 'spectrum_view.dart';

/// Everything the UI draws for one analysis frame.
class AnalysisSnapshot {
  const AnalysisSnapshot({
    required this.timestampMs,
    required this.stableNote,
    required this.detectedHz,
    required this.confidence,
    required this.amplitudeLinear,
    required this.amplitudeDb,
    required this.gateOpen,
    required this.gateThresholdDb,
    required this.noiseFloorDb,
    required this.salienceBySemitone,
    required this.salienceLowestMidi,
    required this.pitchClassEnergy,
    required this.spectrum,
  });

  factory AnalysisSnapshot.empty() => AnalysisSnapshot(
        timestampMs: 0,
        stableNote: null,
        detectedHz: null,
        confidence: 0,
        amplitudeLinear: 0,
        amplitudeDb: -90,
        gateOpen: false,
        gateThresholdDb: -65,
        noiseFloorDb: -90,
        salienceBySemitone: Float32List(0),
        salienceLowestMidi: 0,
        pitchClassEnergy: Float32List(12),
        spectrum: SpectrumView.empty(),
      );

  final int timestampMs;

  /// Debounced note, or null. Null means "no trustworthy note"; never a guess.
  final NoteEvent? stableNote;

  /// Raw detected frequency for this frame (null if none passed the filters).
  final double? detectedHz;

  /// Pitch clarity 0..1 of the latest accepted estimate (0 if none).
  final double confidence;

  final double amplitudeLinear;
  final double amplitudeDb;
  final bool gateOpen;
  final double gateThresholdDb;
  final double noiseFloorDb;

  /// Strength 0..1 per semitone, starting at MIDI [salienceLowestMidi].
  final Float32List salienceBySemitone;
  final int salienceLowestMidi;

  /// 12 values 0..1 (C first), decayed over time.
  final Float32List pitchClassEnergy;

  final SpectrumView spectrum;
}
