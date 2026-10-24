import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/accidental_preference.dart';
import 'package:octune/domain/note_display.dart';
import 'package:octune/domain/note_name.dart';

void main() {
  test('sharps and flats spellings', () {
    expect(
      noteDisplayName(NoteName.fSharp, AccidentalPreference.sharps),
      'F♯',
    );
    expect(
      noteDisplayName(NoteName.fSharp, AccidentalPreference.flats),
      'G♭',
    );
    expect(
      noteDisplayName(NoteName.aSharp, AccidentalPreference.sharps),
      'A♯',
    );
    expect(
      noteDisplayName(NoteName.aSharp, AccidentalPreference.flats),
      'B♭',
    );
    expect(noteDisplayName(NoteName.a, AccidentalPreference.sharps), 'A');
    expect(noteDisplayName(NoteName.c, AccidentalPreference.flats), 'C');
  });
}
