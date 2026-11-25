import 'detector_settings.dart';

/// Instrument presets: a frequency search range, replacing a calibration UI.
enum DetectionPreset {
  fullRange('Full range', 65, 2100),
  voice('Voice', 70, 1100),
  guitar('Guitar', 75, 1400),

  /// Bass guitar E1 is 41 Hz, below what the default 2048-sample window can
  /// search (about 43 Hz), so the lowest note is clamped by the detector.
  bass('Bass', 40, 500),
  violin('Violin', 190, 2700),
  flute('Flute', 250, 2200);

  const DetectionPreset(this.label, this.minHz, this.maxHz);

  final String label;
  final double minHz;
  final double maxHz;

  DetectorSettings applyTo(DetectorSettings settings) =>
      settings.copyWith(minFrequencyHz: minHz, maxFrequencyHz: maxHz);

  /// The preset whose range equals [settings]', or null for a custom range.
  static DetectionPreset? matching(DetectorSettings settings) {
    for (final p in values) {
      if (p.minHz == settings.minFrequencyHz &&
          p.maxHz == settings.maxFrequencyHz) {
        return p;
      }
    }
    return null;
  }
}
