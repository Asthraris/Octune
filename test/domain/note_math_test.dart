import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/accidental_preference.dart';
import 'package:octune/domain/note_display.dart';
import 'package:octune/domain/note_math.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/note_reading.dart';

void main() {
  test('A4 at 440 Hz is A4 with 0 cents', () {
    final NoteReading reading = nearestNote(440);
    expect(reading.noteName, NoteName.a);
    expect(reading.octave, 4);
    expect(reading.midiNumber, 69);
    expect(reading.centsOffset, closeTo(0, 1e-6));
    expect(frequencyToMidi(440), closeTo(69, 1e-9));
    expect(midiToFrequency(69), closeTo(440, 1e-9));
  });

  test('261.63 Hz is C4', () {
    final NoteReading reading = nearestNote(261.63);
    expect(reading.noteName, NoteName.c);
    expect(reading.octave, 4);
    expect(reading.midiNumber, 60);
    expect(reading.centsOffset, closeTo(0, 1));
  });

  test('466.16 Hz is A♯4 or B♭4 by preference', () {
    final NoteReading reading = nearestNote(466.16);
    expect(reading.noteName, NoteName.aSharp);
    expect(reading.octave, 4);
    expect(
      noteDisplayName(reading.noteName, AccidentalPreference.sharps),
      'A♯',
    );
    expect(
      noteDisplayName(reading.noteName, AccidentalPreference.flats),
      'B♭',
    );
  });

  test('220 Hz is A3', () {
    final NoteReading reading = nearestNote(220);
    expect(reading.noteName, NoteName.a);
    expect(reading.octave, 3);
    expect(reading.midiNumber, 57);
  });

  test('445 Hz is A4 about +20 cents', () {
    final NoteReading reading = nearestNote(445);
    expect(reading.noteName, NoteName.a);
    expect(reading.octave, 4);
    expect(reading.centsOffset, closeTo(20, 1));
  });

  test('a4=415 shifts results', () {
    final NoteReading concert = nearestNote(415);
    expect(concert.noteName, NoteName.gSharp);
    expect(concert.octave, 4);

    final NoteReading baroqueA = nearestNote(415, a4: 415);
    expect(baroqueA.noteName, NoteName.a);
    expect(baroqueA.octave, 4);
    expect(baroqueA.centsOffset, closeTo(0, 1e-6));
    expect(frequencyToMidi(415, a4: 415), closeTo(69, 1e-9));
    expect(midiToFrequency(69, a4: 415), closeTo(415, 1e-9));
  });

  test('octave changes at C', () {
    expect(nearestNote(midiToFrequency(59)).octave, 3);
    expect(nearestNote(midiToFrequency(60)).noteName, NoteName.c);
    expect(nearestNote(midiToFrequency(60)).octave, 4);
  });
}
