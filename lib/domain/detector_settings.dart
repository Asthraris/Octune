import 'dart:math' as math;

/// User-adjustable detection parameters. Immutable; use [validated] to clamp.
class DetectorSettings {
  const DetectorSettings({
    this.a4Hz = 440,
    this.noiseGate = 0.33,
    this.minConfidence = 0.85,
    this.minFrequencyHz = 65,
    this.maxFrequencyHz = 2100,
  });

  static const double a4Min = 415;
  static const double a4Max = 466;

  /// Reference pitch for A4, 415-466 Hz.
  final double a4Hz;

  /// 0 (sensitive) .. 1 (strict). Mapped to a dB margin by the noise gate.
  final double noiseGate;

  /// Minimum pitch clarity (0..1) to accept a note. The YIN detector itself
  /// never reports clarity below ~0.8, so values under that have no effect.
  final double minConfidence;

  final double minFrequencyHz;
  final double maxFrequencyHz;

  DetectorSettings validated() {
    final minHz = minFrequencyHz.clamp(20.0, 4000.0).toDouble();
    final maxHz = maxFrequencyHz.clamp(minHz * 1.26, 8000.0).toDouble();
    return DetectorSettings(
      a4Hz: a4Hz.clamp(a4Min, a4Max).toDouble(),
      noiseGate: noiseGate.clamp(0.0, 1.0).toDouble(),
      minConfidence: minConfidence.clamp(0.0, 1.0).toDouble(),
      minFrequencyHz: minHz,
      maxFrequencyHz: math.max(maxHz, minHz * 1.26),
    );
  }

  DetectorSettings copyWith({
    double? a4Hz,
    double? noiseGate,
    double? minConfidence,
    double? minFrequencyHz,
    double? maxFrequencyHz,
  }) =>
      DetectorSettings(
        a4Hz: a4Hz ?? this.a4Hz,
        noiseGate: noiseGate ?? this.noiseGate,
        minConfidence: minConfidence ?? this.minConfidence,
        minFrequencyHz: minFrequencyHz ?? this.minFrequencyHz,
        maxFrequencyHz: maxFrequencyHz ?? this.maxFrequencyHz,
      );

  @override
  bool operator ==(Object other) =>
      other is DetectorSettings &&
      other.a4Hz == a4Hz &&
      other.noiseGate == noiseGate &&
      other.minConfidence == minConfidence &&
      other.minFrequencyHz == minFrequencyHz &&
      other.maxFrequencyHz == maxFrequencyHz;

  @override
  int get hashCode =>
      Object.hash(a4Hz, noiseGate, minConfidence, minFrequencyHz, maxFrequencyHz);
}
