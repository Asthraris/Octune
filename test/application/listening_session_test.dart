import 'package:flutter_test/flutter_test.dart';
import 'package:octune/application/listening_session.dart';
import 'package:octune/audio/audio_input.dart';
import 'package:octune/audio/fake_audio_input.dart';
import 'package:octune/domain/analysis_snapshot.dart';
import 'package:octune/domain/note_change.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/recent_notes.dart';
import 'package:octune/engine/pitch_pipeline.dart';

import '../helpers/rig.dart';
import '../helpers/signals.dart';

class Harness {
  Harness() {
    session = ListeningSession(
      input: input,
      analyzer: PitchPipeline.standard(),
      onSnapshot: (s, r) {
        snapshots.add(s);
        recents.add(r);
      },
      onNoteChange: changes.add,
      onInputEvent: events.add,
    );
  }

  final input = FakeAudioInput();
  final snapshots = <AnalysisSnapshot>[];
  final recents = <RecentNotes>[];
  final changes = <NoteChange>[];
  final events = <AudioInputEvent>[];
  late final ListeningSession session;

  Future<void> play(List<Segment> segments) async {
    final signal = render(segments);
    for (var i = 0; i + 1024 <= signal.length; i += 1024) {
      input.feed(signal.sublist(i, i + 1024));
    }
    await settle();
  }
}

String? name(NoteChange c) => c.note == null
    ? null
    : '${c.note!.noteName.asciiName}${c.note!.octave}';

void main() {
  test('reports note starts, changes and ends, once each', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [
      Segment(0, 0.5),
      Segment(440, 0.7),
      Segment(0, 0.7),
      Segment(523.25, 0.7),
    ]);
    expect(h.changes.map(name).toList(), equals(['A4', null, 'C5']));
    await h.session.stop();
    expect(h.changes.map(name).toList(), equals(['A4', null, 'C5', null]));
  });

  test('change timestamps are in order and come from the audio timeline', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [Segment(0, 0.5), Segment(440, 0.7), Segment(0, 0.7)]);
    final t = h.changes.map((c) => c.tMs).toList();
    expect(t.length, 2);
    expect(t[0], inInclusiveRange(500, 750)); // note starts at 0.5 s
    expect(t[1], greaterThan(t[0]));
  });

  test('snapshots are throttled but note changes publish immediately', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [Segment(0, 0.5), Segment(440, 1.5)]);
    expect(h.session.framesProcessed, greaterThan(60));
    final ratio = h.session.snapshotsPublished / h.session.framesProcessed;
    expect(ratio, inInclusiveRange(0.4, 0.7)); // about every 2nd frame
    // the snapshot carrying the first note appears at the note-change time
    final first = h.snapshots.firstWhere((s) => s.stableNote != null);
    expect(first.timestampMs, h.changes.first.tMs);
  });

  test('published snapshots without a change are at least 30 ms apart', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [Segment(0, 0.5), Segment(440, 1.5)]);
    for (var i = 1; i < h.snapshots.length; i++) {
      final a = h.snapshots[i - 1];
      final b = h.snapshots[i];
      final changed = (a.stableNote?.midiNumber != b.stableNote?.midiNumber) ||
          a.gateOpen != b.gateOpen;
      if (!changed) {
        expect(b.timestampMs - a.timestampMs, greaterThanOrEqualTo(30));
      }
    }
  });

  test('recent notes follow the played notes', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [
      Segment(0, 0.5),
      Segment(440, 0.6),
      Segment(0, 0.5),
      Segment(523.25, 0.6),
    ]);
    expect(h.session.recent.midiNotes, equals([69])); // A4 behind the sounding C5
    await h.session.stop();
    expect(h.recents.last.midiNotes, equals([72, 69])); // after stop: C5 then A4
  });

  test('stop publishes an empty snapshot and is safe to repeat', () async {
    final h = Harness();
    await h.session.start();
    await h.play(const [Segment(0, 0.5), Segment(440, 0.6)]);
    await h.session.stop();
    expect(h.snapshots.last.stableNote, isNull);
    expect(h.snapshots.last.spectrum.magnitudesDb, isEmpty);
    expect(h.input.isRunning, isFalse);
    final n = h.snapshots.length;
    await h.session.stop();
    expect(h.snapshots.length, n);
    expect(h.session.isActive, isFalse);
  });

  test('frames arriving after stop are ignored', () async {
    final h = Harness();
    await h.session.start();
    await h.session.stop();
    final before = h.session.framesProcessed;
    h.input.feed(render(const [Segment(440, 0.3)]));
    await settle();
    expect(h.session.framesProcessed, before);
  });

  test('a failing input rethrows and leaves the session inactive', () async {
    final h = Harness();
    h.input.failOnStart = StateError('no microphone');
    Object? caught;
    try {
      await h.session.start();
    } catch (e) {
      caught = e;
    }
    expect(caught is StateError, isTrue);
    expect(h.session.isActive, isFalse);
  });

  test('input events are forwarded', () async {
    final h = Harness();
    await h.session.start();
    h.input.emit(const AudioInputEvent(AudioInputEventType.interrupted));
    h.input.emit(const AudioInputEvent(AudioInputEventType.resumed));
    await settle();
    expect(h.events.map((e) => e.type).toList(),
        equals([AudioInputEventType.interrupted, AudioInputEventType.resumed]));
  });
}
