/// Twelve chromatic pitch classes. Index 0 is C (MIDI pitch class).
enum NoteName {
  c,
  cSharp,
  d,
  dSharp,
  e,
  f,
  fSharp,
  g,
  gSharp,
  a,
  aSharp,
  b;

  /// Canonical JSON / MIDI spelling (always sharps): C, C#, D, …
  String get jsonName {
    return switch (this) {
      NoteName.c => 'C',
      NoteName.cSharp => 'C#',
      NoteName.d => 'D',
      NoteName.dSharp => 'D#',
      NoteName.e => 'E',
      NoteName.f => 'F',
      NoteName.fSharp => 'F#',
      NoteName.g => 'G',
      NoteName.gSharp => 'G#',
      NoteName.a => 'A',
      NoteName.aSharp => 'A#',
      NoteName.b => 'B',
    };
  }

  static NoteName fromPitchClass(int pitchClass) {
    return NoteName.values[((pitchClass % 12) + 12) % 12];
  }

  static NoteName fromMidi(int midiNumber) => fromPitchClass(midiNumber);

  /// Parses canonical sharp names and flat aliases (`A#`, `Bb`, `A♯`, `B♭`).
  static NoteName parse(String value) {
    return switch (value) {
      'C' => NoteName.c,
      'C#' || 'C♯' || 'Db' || 'D♭' => NoteName.cSharp,
      'D' => NoteName.d,
      'D#' || 'D♯' || 'Eb' || 'E♭' => NoteName.dSharp,
      'E' => NoteName.e,
      'F' => NoteName.f,
      'F#' || 'F♯' || 'Gb' || 'G♭' => NoteName.fSharp,
      'G' => NoteName.g,
      'G#' || 'G♯' || 'Ab' || 'A♭' => NoteName.gSharp,
      'A' => NoteName.a,
      'A#' || 'A♯' || 'Bb' || 'B♭' => NoteName.aSharp,
      'B' => NoteName.b,
      _ => throw FormatException('Unknown note name', value),
    };
  }
}
