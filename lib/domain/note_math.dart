import 'dart:math' as math;

import 'note_name.dart';

const double kStandardA4Hz = 440.0;
const int kMidiA4 = 69;

/// Fractional MIDI number of [hz]. A4 (= [a4]) is MIDI 69.
double frequencyToMidi(double hz, {double a4 = kStandardA4Hz}) {
  if (!(hz > 0) || !hz.isFinite) {
    throw ArgumentError.value(hz, 'hz', 'must be positive and finite');
  }
  return kMidiA4 + 12 * math.log(hz / a4) / math.ln2;
}

/// Frequency of a (possibly fractional) MIDI number.
double midiToFrequency(double midi, {double a4 = kStandardA4Hz}) =>
    a4 * math.pow(2, (midi - kMidiA4) / 12).toDouble();

/// A pitch snapped to the nearest equal-tempered note.
class NoteReading {
  const NoteReading({
    required this.noteName,
    required this.octave,
    required this.midiNumber,
    required this.centsOffset,
  });

  /// Builds a reading from an integer MIDI note and a cents offset.
  /// Octave numbering changes at C (MIDI 60 = C4).
  factory NoteReading.fromMidi(int midi, {double cents = 0}) => NoteReading(
        noteName: noteNameFromPitchClass(midi),
        octave: (midi / 12).floor() - 1,
        midiNumber: midi,
        centsOffset: cents,
      );

  final NoteName noteName;
  final int octave;
  final int midiNumber;

  /// Deviation from the note center, in cents (negative = flat).
  final double centsOffset;

  /// Exact (fractional) MIDI position this reading represents.
  double get fractionalMidi => midiNumber + centsOffset / 100;

  @override
  bool operator ==(Object other) =>
      other is NoteReading &&
      other.midiNumber == midiNumber &&
      other.centsOffset == centsOffset;

  @override
  int get hashCode => Object.hash(midiNumber, centsOffset);

  @override
  String toString() =>
      'NoteReading(${noteName.asciiName}$octave, ${centsOffset.toStringAsFixed(1)}¢)';
}

/// Snaps [hz] to the nearest note. [a4] is the reference tuning.
NoteReading nearestNote(double hz, {double a4 = kStandardA4Hz}) {
  final midi = frequencyToMidi(hz, a4: a4);
  final rounded = midi.round();
  return NoteReading.fromMidi(rounded, cents: (midi - rounded) * 100);
}
