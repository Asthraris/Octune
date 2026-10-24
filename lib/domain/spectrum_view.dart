import 'dart:typed_data';

final class SpectrumView {
  SpectrumView({
    required Float32List magnitudesDb,
    required this.minHz,
    required this.maxHz,
    required this.peakHz,
    required this.peakDb,
  }) : magnitudesDb = Float32List.fromList(magnitudesDb);

  factory SpectrumView.empty() => _empty;

  static final SpectrumView _empty = SpectrumView(
    magnitudesDb: Float32List(0),
    minHz: 0,
    maxHz: 0,
    peakHz: null,
    peakDb: 0,
  );

  /// Log-spaced bin magnitudes in dB.
  final Float32List magnitudesDb;
  final double minHz;
  final double maxHz;
  final double? peakHz;
  final double peakDb;

  @override
  bool operator ==(Object other) {
    return other is SpectrumView &&
        _float32Equals(other.magnitudesDb, magnitudesDb) &&
        other.minHz == minHz &&
        other.maxHz == maxHz &&
        other.peakHz == peakHz &&
        other.peakDb == peakDb;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(magnitudesDb),
      minHz,
      maxHz,
      peakHz,
      peakDb,
    );
  }
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
