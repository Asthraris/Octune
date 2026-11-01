import 'dart:typed_data';

/// What the signal panel draws: log-spaced spectrum magnitudes plus the
/// highest peak. [peakHz] is the loudest spectral peak, which can be a
/// harmonic, so it need not equal the detected pitch.
class SpectrumView {
  const SpectrumView({
    required this.magnitudesDb,
    required this.minHz,
    required this.maxHz,
    this.peakHz,
    this.peakDb = -90,
  });

  factory SpectrumView.empty() => SpectrumView(
        magnitudesDb: Float32List(0),
        minHz: 50,
        maxHz: 4000,
      );

  /// One value per log-spaced bin between [minHz] and [maxHz].
  final Float32List magnitudesDb;
  final double minHz;
  final double maxHz;
  final double? peakHz;
  final double peakDb;
}
