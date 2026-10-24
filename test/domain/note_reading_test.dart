import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/note_reading.dart';

void main() {
  test('equality', () {
    const NoteReading a = NoteReading(
      noteName: NoteName.c,
      octave: 4,
      midiNumber: 60,
      centsOffset: 0,
    );
    const NoteReading b = NoteReading(
      noteName: NoteName.c,
      octave: 4,
      midiNumber: 60,
      centsOffset: 0,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
