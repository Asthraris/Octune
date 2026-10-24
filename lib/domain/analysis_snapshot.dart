import 'dart:typed_data';

import 'note_event.dart';
import 'spectrum_view.dart';

final class AnalysisSnapshot {
  AnalysisSnapshot({
    required this.timestampMs,
    required this.stableNote,
    required this.detectedHz,
    required this.confidence,
    required this.amplitudeLinear,
    required this.amplitudeDb,
    required this.gateOpen,
    required this.gateThresholdDb,
    required this.noiseFloorDb,
    required Float32List salienceBySemitone,
    required this.salienceLowestMidi,
    required Float32List pitchClassEnergy,
    required this.spectrum,
  }) : salienceBySemitone = Float32List.fromList(salienceBySemitone),
       pitchClassEnergy = _copyPitchClassEnergy(pitchClassEnergy);

  factory AnalysisSnapshot.empty() => _empty;

  static final AnalysisSnapshot _empty = AnalysisSnapshot(
    timestampMs: 0,
    stableNote: null,
    detectedHz: null,
    confidence: 0,
    amplitudeLinear: 0,
    amplitudeDb: 0,
    gateOpen: false,
    gateThresholdDb: 0,
    noiseFloorDb: 0,
    salienceBySemitone: Float32List(0),
    salienceLowestMidi: 0,
    pitchClassEnergy: Float32List(12),
    spectrum: SpectrumView.empty(),
  );

  final int timestampMs;
  final NoteEvent? stableNote;
  final double? detectedHz;
  final double confidence;
  final double amplitudeLinear;
  final double amplitudeDb;
  final bool gateOpen;
  final double gateThresholdDb;
  final double noiseFloorDb;

  /// Top strip: energy per semitone, starting at [salienceLowestMidi].
  final Float32List salienceBySemitone;
  final int salienceLowestMidi;

  /// Note ring: 12 values, index 0 = C.
  final Float32List pitchClassEnergy;
  final SpectrumView spectrum;

  @override
  bool operator ==(Object other) {
    return other is AnalysisSnapshot &&
        other.timestampMs == timestampMs &&
        other.stableNote == stableNote &&
        other.detectedHz == detectedHz &&
        other.confidence == confidence &&
        other.amplitudeLinear == amplitudeLinear &&
        other.amplitudeDb == amplitudeDb &&
        other.gateOpen == gateOpen &&
        other.gateThresholdDb == gateThresholdDb &&
        other.noiseFloorDb == noiseFloorDb &&
        _float32Equals(other.salienceBySemitone, salienceBySemitone) &&
        other.salienceLowestMidi == salienceLowestMidi &&
        _float32Equals(other.pitchClassEnergy, pitchClassEnergy) &&
        other.spectrum == spectrum;
  }

  @override
  int get hashCode {
    return Object.hash(
      timestampMs,
      stableNote,
      detectedHz,
      confidence,
      amplitudeLinear,
      amplitudeDb,
      gateOpen,
      gateThresholdDb,
      noiseFloorDb,
      Object.hashAll(salienceBySemitone),
      salienceLowestMidi,
      Object.hashAll(pitchClassEnergy),
      spectrum,
    );
  }
}

Float32List _copyPitchClassEnergy(Float32List energy) {
  if (energy.length != 12) {
    throw ArgumentError.value(
      energy.length,
      'pitchClassEnergy',
      'must contain 12 pitch-class values',
    );
  }
  return Float32List.fromList(energy);
}

bool _float32Equals(Float32List a, Float32List b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
