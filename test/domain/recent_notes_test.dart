import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_event.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/recent_notes.dart';

void main() {
  NoteEvent note(NoteName name, int octave, {int tMs = 0}) {
    return NoteEvent(
      tMs: tMs,
      noteName: name,
      octave: octave,
      cents: 0,
      amp: 1,
      conf: 1,
    );
  }

  test('C4, C4, A4, E5 -> current E5, recent [A4, C4]', () {
    RecentNotes buffer = RecentNotes();
    buffer = buffer.push(note(NoteName.c, 4, tMs: 1));
    buffer = buffer.push(note(NoteName.c, 4, tMs: 2));
    buffer = buffer.push(note(NoteName.a, 4, tMs: 3));
    buffer = buffer.push(note(NoteName.e, 5, tMs: 4));

    expect(buffer.current?.noteName, NoteName.e);
    expect(buffer.current?.octave, 5);
    expect(buffer.notes, hasLength(2));
    expect(buffer.notes[0].noteName, NoteName.a);
    expect(buffer.notes[0].octave, 4);
    expect(buffer.notes[1].noteName, NoteName.c);
    expect(buffer.notes[1].octave, 4);
  });

  test('silence does not push', () {
    final RecentNotes buffer = RecentNotes()
        .push(note(NoteName.c, 4))
        .push(note(NoteName.a, 4));
    final RecentNotes afterSilence = buffer.push(null);

    expect(identical(afterSilence, buffer), isTrue);
    expect(afterSilence.current?.noteName, NoteName.a);
    expect(afterSilence.notes.single.noteName, NoteName.c);
  });

  test('same note different octave is distinct', () {
    final RecentNotes buffer = RecentNotes()
        .push(note(NoteName.c, 4))
        .push(note(NoteName.c, 5));
    expect(buffer.current?.octave, 5);
    expect(buffer.notes.single.octave, 4);
  });

  test('capacity keeps last N excluding current', () {
    RecentNotes buffer = RecentNotes(capacity: 3);
    buffer = buffer.push(note(NoteName.c, 4));
    buffer = buffer.push(note(NoteName.d, 4));
    buffer = buffer.push(note(NoteName.e, 4));
    buffer = buffer.push(note(NoteName.f, 4));
    buffer = buffer.push(note(NoteName.g, 4));

    expect(buffer.current?.noteName, NoteName.g);
    expect(buffer.notes, hasLength(3));
    expect(buffer.notes.map((NoteEvent e) => e.noteName).toList(), <NoteName>[
      NoteName.f,
      NoteName.e,
      NoteName.d,
    ]);
  });
}
