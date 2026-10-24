import 'dart:math' as math;

final class DetectorSettings {
  DetectorSettings({
    double a4Hz = 440,
    double noiseGate = 0,
    double minConfidence = 0,
    double minFrequencyHz = 65,
    double maxFrequencyHz = 2100,
  }) : a4Hz = a4Hz.clamp(415, 466).toDouble(),
       noiseGate = noiseGate.clamp(0, 1).toDouble(),
       minConfidence = minConfidence.clamp(0, 1).toDouble(),
       minFrequencyHz = math.min(minFrequencyHz, maxFrequencyHz),
       maxFrequencyHz = math.max(minFrequencyHz, maxFrequencyHz);

  final double a4Hz;
  final double noiseGate;
  final double minConfidence;
  final double minFrequencyHz;
  final double maxFrequencyHz;

  @override
  bool operator ==(Object other) {
    return other is DetectorSettings &&
        other.a4Hz == a4Hz &&
        other.noiseGate == noiseGate &&
        other.minConfidence == minConfidence &&
        other.minFrequencyHz == minFrequencyHz &&
        other.maxFrequencyHz == maxFrequencyHz;
  }

  @override
  int get hashCode {
    return Object.hash(
      a4Hz,
      noiseGate,
      minConfidence,
      minFrequencyHz,
      maxFrequencyHz,
    );
  }
}
