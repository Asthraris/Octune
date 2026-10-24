import 'note_name.dart';

final class NoteReading {
  const NoteReading({
    required this.noteName,
    required this.octave,
    required this.midiNumber,
    required this.centsOffset,
  });

  final NoteName noteName;
  final int octave;
  final int midiNumber;
  final double centsOffset;

  @override
  bool operator ==(Object other) {
    return other is NoteReading &&
        other.noteName == noteName &&
        other.octave == octave &&
        other.midiNumber == midiNumber &&
        other.centsOffset == centsOffset;
  }

  @override
  int get hashCode => Object.hash(noteName, octave, midiNumber, centsOffset);
}
