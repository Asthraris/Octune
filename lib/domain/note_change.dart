import 'note_event.dart';

/// A change of the stable note: a note starting (or changing) when [note] is
/// non-null, or the note ending when null. The input for later recording.
class NoteChange {
  const NoteChange(this.tMs, this.note);

  final int tMs;
  final NoteEvent? note;

  bool get isOff => note == null;

  @override
  String toString() => isOff ? 'NoteChange($tMs ms: off)' : 'NoteChange($tMs ms: $note)';
}
