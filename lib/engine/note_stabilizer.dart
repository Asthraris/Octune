import '../domain/note_math.dart';

/// Turns noisy per-frame readings into a steady note.
///
/// * Median smoothing over [medianWindow] frames removes short outliers.
/// * A different note must win for [confirmFrames] consecutive frames before
///   the output switches; an exact +/-12 semitone jump needs
///   [octaveConfirmFrames] (octave errors are the commonest false jump).
/// * Hysteresis: the smoothed pitch must pass [hysteresisSemitones] beyond
///   the half-semitone boundary before a neighbour can win, so vibrato near a
///   boundary does not flicker.
/// * After [releaseFrames] consecutive empty frames the note is released.
///   Shorter gaps hold the last note.
///
/// The returned reading carries live cents relative to the stable note,
/// computed from the smoothed pitch.
class NoteStabilizer {
  NoteStabilizer({
    this.medianWindow = 5,
    this.confirmFrames = 2,
    this.octaveConfirmFrames = 6,
    this.releaseFrames = 6,
    this.hysteresisSemitones = 0.1,
  });

  final int medianWindow;
  final int confirmFrames;
  final int octaveConfirmFrames;
  final int releaseFrames;
  final double hysteresisSemitones;

  final List<double?> _window = [];
  int? _stableMidi;
  double _lastMedian = 0;
  int? _pendingMidi;
  int _pendingCount = 0;
  int _nullRun = 0;

  void reset() {
    _window.clear();
    _stableMidi = null;
    _pendingMidi = null;
    _pendingCount = 0;
    _nullRun = 0;
  }

  NoteReading? process(NoteReading? reading) {
    _window.add(reading?.fractionalMidi);
    if (_window.length > medianWindow) _window.removeAt(0);

    if (reading == null) {
      _nullRun++;
      if (_nullRun >= releaseFrames) {
        reset();
        return null;
      }
      return _current();
    }
    _nullRun = 0;

    final median = _median();
    _lastMedian = median;
    final candidate = median.round();
    final stable = _stableMidi;

    if (stable == null) {
      _track(candidate);
      if (_pendingCount >= confirmFrames) {
        _stableMidi = candidate;
        _clearPending();
      }
    } else {
      final deviation = (median - stable).abs();
      if (candidate == stable || deviation < 0.5 + hysteresisSemitones) {
        _clearPending();
      } else {
        _track(candidate);
        final octaveJump = (candidate - stable).abs() % 12 == 0;
        final needed = octaveJump ? octaveConfirmFrames : confirmFrames;
        if (_pendingCount >= needed) {
          _stableMidi = candidate;
          _clearPending();
        }
      }
    }
    return _current();
  }

  NoteReading? _current() {
    final midi = _stableMidi;
    if (midi == null) return null;
    return NoteReading.fromMidi(midi, cents: (_lastMedian - midi) * 100);
  }

  void _track(int candidate) {
    if (candidate == _pendingMidi) {
      _pendingCount++;
    } else {
      _pendingMidi = candidate;
      _pendingCount = 1;
    }
  }

  void _clearPending() {
    _pendingMidi = null;
    _pendingCount = 0;
  }

  double _median() {
    final values = <double>[
      for (final v in _window)
        if (v != null) v,
    ]..sort();
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
}
