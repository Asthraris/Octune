import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/note_math.dart';
import 'spectrum_analyzer.dart';

/// Folds spectral peaks into 12 pitch classes (C first) with attack-instant,
/// exponentially decaying energy: the data for the note ring.
///
/// Each frame, peaks contribute relative power (strongest = 1), normalised so
/// the loudest class is 1, then scaled by a presence factor (how far the
/// strongest peak is above the noise floor, saturating at [presenceRangeDb]).
/// Silence therefore shows 0, and harmonics add only a little to their class.
class PitchClassEnergy {
  PitchClassEnergy({this.decayTauMs = 300, this.presenceRangeDb = 30});

  final double decayTauMs;
  final double presenceRangeDb;

  final Float64List _energy = Float64List(12);
  final Float64List _instant = Float64List(12);

  /// Advances by [dtMs] and returns a copy of the 12 current values (0..1).
  Float32List update(
    List<SpectralPeak> peaks,
    double dtMs, {
    double a4Hz = kStandardA4Hz,
    double noiseFloorDb = -90,
  }) {
    _instant.fillRange(0, 12, 0);
    if (peaks.isNotEmpty) {
      var strongest = peaks.first.magnitudeDb;
      for (final p in peaks) {
        if (p.magnitudeDb > strongest) strongest = p.magnitudeDb;
      }
      for (final p in peaks) {
        if (!(p.frequencyHz > 0)) continue;
        final pc = frequencyToMidi(p.frequencyHz, a4: a4Hz).round() % 12;
        _instant[pc] += math.pow(10, (p.magnitudeDb - strongest) / 10);
      }
      var maxInstant = 0.0;
      for (final v in _instant) {
        if (v > maxInstant) maxInstant = v;
      }
      final presence =
          ((strongest - noiseFloorDb) / presenceRangeDb).clamp(0.0, 1.0);
      if (maxInstant > 0) {
        for (var i = 0; i < 12; i++) {
          _instant[i] = _instant[i] / maxInstant * presence;
        }
      }
    }
    final decay = math.exp(-dtMs / decayTauMs);
    for (var i = 0; i < 12; i++) {
      _energy[i] = math.max(_instant[i], _energy[i] * decay);
    }
    return Float32List.fromList(_energy);
  }

  void reset() => _energy.fillRange(0, 12, 0);
}
