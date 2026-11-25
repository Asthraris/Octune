import 'note_math.dart';

/// The last few distinct notes played, newest first, for the "c4 a4" strip.
///
/// * Repeats of the same note+octave are ignored (C4, C4 is one note).
/// * While a note is sounding it is excluded from [midiNotes], because the
///   big display already shows it.
/// * Silence never adds an entry; after silence the list includes the note
///   just released.
class RecentNotes {
  const RecentNotes._(this._played, this._sounding, this.maxCount);

  factory RecentNotes.empty({int maxCount = 3}) =>
      RecentNotes._(const [], false, maxCount);

  final List<int> _played; // MIDI numbers, newest first
  final bool _sounding;
  final int maxCount;

  /// Feed the stable MIDI note each frame (null when nothing is sounding).
  RecentNotes update(int? currentMidi) {
    if (currentMidi == null) {
      return _sounding ? RecentNotes._(_played, false, maxCount) : this;
    }
    if (_played.isNotEmpty && _played.first == currentMidi) {
      return _sounding ? this : RecentNotes._(_played, true, maxCount);
    }
    final next = <int>[currentMidi, ..._played];
    if (next.length > maxCount + 1) next.removeRange(maxCount + 1, next.length);
    return RecentNotes._(List.unmodifiable(next), true, maxCount);
  }

  /// Recent notes to display, newest first (at most [maxCount]).
  List<int> get midiNotes =>
      (_sounding ? _played.skip(1) : _played).take(maxCount).toList();

  List<NoteReading> get notes =>
      [for (final m in midiNotes) NoteReading.fromMidi(m)];

  @override
  bool operator ==(Object other) =>
      other is RecentNotes &&
      other.maxCount == maxCount &&
      other._sounding == _sounding &&
      _listEquals(other._played, _played);

  @override
  int get hashCode => Object.hash(maxCount, _sounding, Object.hashAll(_played));

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'RecentNotes(${midiNotes.join(', ')})';
}
