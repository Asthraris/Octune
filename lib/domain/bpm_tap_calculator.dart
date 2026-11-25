/// Tap-tempo: averages the last few intervals between taps.
class BpmTapCalculator {
  BpmTapCalculator({this.maxIntervals = 4, this.resetAfterMs = 2000});

  /// Number of intervals averaged (so maxIntervals + 1 taps are kept).
  final int maxIntervals;

  /// A pause longer than this starts a fresh tap sequence.
  final int resetAfterMs;

  final List<int> _taps = [];

  /// Registers a tap at [nowMs]. Returns the BPM estimate, or null until
  /// there are two taps. The result is not clamped to the metronome range.
  double? tap(int nowMs) {
    if (_taps.isNotEmpty && nowMs - _taps.last > resetAfterMs) _taps.clear();
    if (_taps.isNotEmpty && nowMs <= _taps.last) return _estimate();
    _taps.add(nowMs);
    while (_taps.length > maxIntervals + 1) {
      _taps.removeAt(0);
    }
    return _estimate();
  }

  double? _estimate() {
    if (_taps.length < 2) return null;
    final avg = (_taps.last - _taps.first) / (_taps.length - 1);
    return avg <= 0 ? null : 60000 / avg;
  }

  void reset() => _taps.clear();
}
