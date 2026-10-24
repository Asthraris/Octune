import 'accidental_preference.dart';
import 'note_name.dart';

/// Display spelling for a pitch class. Sharps use ♯; flats use ♭.
String noteDisplayName(NoteName note, AccidentalPreference preference) {
  return switch (preference) {
    AccidentalPreference.sharps => switch (note) {
      NoteName.c => 'C',
      NoteName.cSharp => 'C♯',
      NoteName.d => 'D',
      NoteName.dSharp => 'D♯',
      NoteName.e => 'E',
      NoteName.f => 'F',
      NoteName.fSharp => 'F♯',
      NoteName.g => 'G',
      NoteName.gSharp => 'G♯',
      NoteName.a => 'A',
      NoteName.aSharp => 'A♯',
      NoteName.b => 'B',
    },
    AccidentalPreference.flats => switch (note) {
      NoteName.c => 'C',
      NoteName.cSharp => 'D♭',
      NoteName.d => 'D',
      NoteName.dSharp => 'E♭',
      NoteName.e => 'E',
      NoteName.f => 'F',
      NoteName.fSharp => 'G♭',
      NoteName.g => 'G',
      NoteName.gSharp => 'A♭',
      NoteName.a => 'A',
      NoteName.aSharp => 'B♭',
      NoteName.b => 'B',
    },
  };
}
