/// The 12 chromatic pitch classes, in semitone order starting at C.
enum NoteName { c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b }

/// How black-key notes are spelled everywhere in the app (decided once).
enum AccidentalPreference { sharps, flats }

const List<String> _sharpNames = [
  'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B',
];
const List<String> _flatNames = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B',
];
const List<String> _asciiSharp = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];
const List<String> _asciiFlat = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B',
];

extension NoteNameX on NoteName {
  /// 0 = C ... 11 = B.
  int get pitchClass => index;

  bool get isAccidental => const <int>{1, 3, 6, 8, 10}.contains(index);

  /// Canonical storage name (always sharps, ASCII). Used in JSON.
  String get asciiName => _asciiSharp[index];

  /// Display name honoring the user's sharp/flat preference.
  String displayName(AccidentalPreference preference) =>
      preference == AccidentalPreference.sharps
          ? _sharpNames[index]
          : _flatNames[index];
}

NoteName noteNameFromPitchClass(int pitchClass) =>
    NoteName.values[((pitchClass % 12) + 12) % 12];

/// Parses "C", "C#", "Db", ... Throws [ArgumentError] on unknown input.
NoteName noteNameFromAscii(String text) {
  var i = _asciiSharp.indexOf(text);
  if (i < 0) i = _asciiFlat.indexOf(text);
  if (i < 0) throw ArgumentError.value(text, 'text', 'Unknown note name');
  return NoteName.values[i];
}
