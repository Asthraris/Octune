import 'note_event.dart';

/// Last [capacity] distinct stable notes, newest first, excluding [current].
final class RecentNotes {
  RecentNotes({int capacity = 3})
    : this._(capacity: capacity < 1 ? 1 : capacity, current: null, notes: const []);

  const RecentNotes._({
    required this.capacity,
    required this.current,
    required this.notes,
  });

  final int capacity;
  final NoteEvent? current;

  /// Newest first. Does not include [current].
  final List<NoteEvent> notes;

  /// Silence ([stableNote] == null) does not change the buffer.
  /// Repeats of the same pitch class + octave are ignored.
  RecentNotes push(NoteEvent? stableNote) {
    if (stableNote == null) {
      return this;
    }
    final NoteEvent? currentNote = current;
    if (currentNote != null && _samePitch(currentNote, stableNote)) {
      return this;
    }
    final List<NoteEvent> nextNotes;
    if (currentNote == null) {
      nextNotes = notes;
    } else {
      nextNotes = <NoteEvent>[
        currentNote,
        ...notes.take(capacity - 1),
      ];
    }
    return RecentNotes._(
      capacity: capacity,
      current: stableNote,
      notes: List<NoteEvent>.unmodifiable(nextNotes),
    );
  }

  static bool _samePitch(NoteEvent a, NoteEvent b) {
    return a.noteName == b.noteName && a.octave == b.octave;
  }

  @override
  bool operator ==(Object other) {
    return other is RecentNotes &&
        other.capacity == capacity &&
        other.current == current &&
        _listEquals(other.notes, notes);
  }

  @override
  int get hashCode => Object.hash(capacity, current, Object.hashAll(notes));
}

bool _listEquals(List<NoteEvent> a, List<NoteEvent> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
