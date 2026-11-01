import 'dart:typed_data';

/// A detected fundamental frequency and how trustworthy it is.
class PitchEstimate {
  const PitchEstimate({required this.frequencyHz, required this.clarity});

  final double frequencyHz;

  /// 0..1. Higher means a cleaner periodic signal.
  final double clarity;
}

/// Result of analysing one frame.
class PitchAnalysis {
  const PitchAnalysis({
    required this.estimate,
    required this.salienceBySemitone,
    required this.salienceLowestMidi,
  });

  /// Null when no pitch passed the detector's own threshold.
  final PitchEstimate? estimate;

  /// Periodicity strength 0..1 per semitone, starting at MIDI
  /// [salienceLowestMidi]. A fresh list on every call (safe to keep).
  final Float32List salienceBySemitone;
  final int salienceLowestMidi;
}

/// Monophonic pitch detection. Implementations must be pure Dart/DSP.
abstract interface class PitchDetector {
  /// Analyses [samples] (mono, -1..1). Frames shorter than the detector's
  /// window yield an empty analysis.
  PitchAnalysis analyze(Float32List samples, int sampleRate);

  /// An analysis with no estimate and all-zero salience, same shape as a
  /// real one. Lets callers skip the expensive work during silence.
  PitchAnalysis emptyAnalysis(int sampleRate);

  /// Restricts the search range (e.g. instrument presets).
  void setFrequencyRange(double minHz, double maxHz);
}
