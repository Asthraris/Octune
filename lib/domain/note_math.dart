import 'dart:math' as math;

import 'note_name.dart';
import 'note_reading.dart';

/// Continuous MIDI number from frequency. A4 (MIDI 69) = [a4] Hz.
///
/// \( f = a4 \cdot 2^{(n-69)/12} \)
double frequencyToMidi(double hz, {double a4 = 440}) {
  if (hz <= 0 || !hz.isFinite) {
    throw ArgumentError.value(hz, 'hz', 'must be a positive finite frequency');
  }
  if (a4 <= 0 || !a4.isFinite) {
    throw ArgumentError.value(a4, 'a4', 'must be a positive finite frequency');
  }
  return 69 + (12 * (math.log(hz / a4) / math.ln2));
}

/// Frequency in Hz for a MIDI number (may be fractional).
double midiToFrequency(double midi, {double a4 = 440}) {
  if (!midi.isFinite) {
    throw ArgumentError.value(midi, 'midi', 'must be finite');
  }
  if (a4 <= 0 || !a4.isFinite) {
    throw ArgumentError.value(a4, 'a4', 'must be a positive finite frequency');
  }
  return a4 * math.pow(2, (midi - 69) / 12);
}

/// Nearest 12-TET note. Octave numbers change at C (C4 = MIDI 60).
NoteReading nearestNote(double hz, {double a4 = 440}) {
  final midiFloat = frequencyToMidi(hz, a4: a4);
  final midiNumber = midiFloat.round();
  final centsOffset = (midiFloat - midiNumber) * 100;
  final octave = (midiNumber / 12).floor() - 1;
  return NoteReading(
    noteName: NoteName.fromMidi(midiNumber),
    octave: octave,
    midiNumber: midiNumber,
    centsOffset: centsOffset,
  );
}
