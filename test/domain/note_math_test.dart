import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_math.dart';
import 'package:octune/domain/note_name.dart';

void main() {
  group('nearestNote', () {
    test('440 Hz is A4 with 0 cents', () {
      final n = nearestNote(440);
      expect(n.noteName, NoteName.a);
      expect(n.octave, 4);
      expect(n.midiNumber, 69);
      expect(n.centsOffset, closeTo(0, 1e-9));
    });
    test('261.63 Hz is C4', () {
      final n = nearestNote(261.63);
      expect(n.noteName, NoteName.c);
      expect(n.octave, 4);
      expect(n.midiNumber, 60);
      expect(n.centsOffset.abs(), lessThan(0.5));
    });
    test('466.16 Hz is A#4 / Bb4', () {
      final n = nearestNote(466.16);
      expect(n.noteName, NoteName.aSharp);
      expect(n.octave, 4);
      expect(n.noteName.displayName(AccidentalPreference.sharps), 'A♯');
      expect(n.noteName.displayName(AccidentalPreference.flats), 'B♭');
    });
    test('220 Hz is A3', () {
      final n = nearestNote(220);
      expect(n.noteName, NoteName.a);
      expect(n.octave, 3);
    });
    test('octave number changes at C (B3 -> C4)', () {
      expect(NoteReading.fromMidi(59).octave, 3);
      expect(NoteReading.fromMidi(60).octave, 4);
    });
    test('445 Hz is A4 about +20 cents', () {
      final n = nearestNote(445);
      expect(n.noteName, NoteName.a);
      expect(n.centsOffset, closeTo(19.56, 0.05));
    });
    test('A4 reference of 415 shifts results', () {
      final n = nearestNote(415, a4: 415);
      expect(n.noteName, NoteName.a);
      expect(n.centsOffset, closeTo(0, 1e-9));
      // 440 Hz is then about +99 cents above A4(415) => rounds to A#4.
      expect(nearestNote(440, a4: 415).noteName, NoteName.aSharp);
    });
    test('negative cents when flat', () {
      expect(nearestNote(435).centsOffset, lessThan(0));
    });
  });

  group('frequency <-> midi', () {
    test('round trip', () {
      for (final f in [82.41, 261.63, 440.0, 1318.51]) {
        expect(midiToFrequency(frequencyToMidi(f)), closeTo(f, 1e-9));
      }
    });
    test('rejects non-positive input', () {
      expect(() => frequencyToMidi(0), throwsArgumentError);
      expect(() => frequencyToMidi(-5), throwsArgumentError);
    });
  });

  group('NoteName', () {
    test('ascii round trip', () {
      for (final n in NoteName.values) {
        expect(noteNameFromAscii(n.asciiName), n);
      }
      expect(noteNameFromAscii('Db'), NoteName.cSharp);
    });
  });
}
