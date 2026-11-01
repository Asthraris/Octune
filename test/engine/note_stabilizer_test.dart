import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_math.dart';
import 'package:octune/engine/note_stabilizer.dart';

NoteReading n(int midi, [double cents = 0]) =>
    NoteReading.fromMidi(midi, cents: cents);

/// Feeds the same reading [count] times, returns the last output.
NoteReading? feed(NoteStabilizer s, NoteReading? r, int count) {
  NoteReading? out;
  for (var i = 0; i < count; i++) {
    out = s.process(r);
  }
  return out;
}

void main() {
  test('nothing in, nothing out', () {
    final s = NoteStabilizer();
    expect(feed(s, null, 20), isNull);
  });

  test('a new note appears only after it persists', () {
    final s = NoteStabilizer();
    expect(s.process(n(69)), isNull); // frame 1: not yet
    expect(s.process(n(69))?.midiNumber, 69); // frame 2: confirmed
  });

  test('a single-frame glitch is ignored', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    expect(s.process(n(75))?.midiNumber, 69);
    expect(feed(s, n(69), 3)?.midiNumber, 69);
  });

  test('a two-frame glitch is ignored (median of 5)', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    s.process(n(75));
    expect(s.process(n(75))?.midiNumber, 69);
    expect(feed(s, n(69), 3)?.midiNumber, 69);
  });

  test('a genuine change of note switches after a few frames', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    final outs = <int?>[];
    for (var i = 0; i < 8; i++) {
      outs.add(s.process(n(72))?.midiNumber);
    }
    expect(outs.first, 69);
    expect(outs.last, 72);
    final switchAt = outs.indexOf(72) + 1;
    expect(switchAt, lessThanOrEqualTo(5)); // ~115 ms at 23 ms/frame
  });

  test('octave blip is rejected; sustained octave change needs more frames', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    // 4 frames up an octave, then back: never switches
    for (var i = 0; i < 4; i++) {
      expect(s.process(n(81))?.midiNumber, 69);
    }
    feed(s, n(69), 4);
    expect(s.process(n(69))?.midiNumber, 69);

    // sustained octave jump finally switches, but later than a normal change
    final outs = <int?>[];
    for (var i = 0; i < 20; i++) {
      outs.add(s.process(n(81))?.midiNumber);
    }
    expect(outs.last, 81);
    expect(outs.indexOf(81) + 1, greaterThan(5));
  });

  test('vibrato of +/-30 cents does not change the note', () {
    final s = NoteStabilizer();
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      final cents = 30 * math.sin(2 * math.pi * 5.5 * i * 0.0232);
      final out = s.process(n(60, cents));
      if (out != null) seen.add(out.midiNumber);
    }
    expect(seen, equals({60}));
  });

  test('pitch hovering near the half-semitone boundary does not flicker', () {
    final s = NoteStabilizer();
    feed(s, n(60, 40), 10);
    final seen = <int>{};
    for (var i = 0; i < 100; i++) {
      final cents = 50 + 6 * math.sin(i * 0.9); // 44..56 cents sharp of C4
      final out = s.process(n(60, cents));
      if (out != null) seen.add(out.midiNumber);
    }
    expect(seen.length, 1);
  });

  test('output cents come from the smoothed pitch relative to the note', () {
    final s = NoteStabilizer();
    final out = feed(s, n(69, -12), 8)!;
    expect(out.midiNumber, 69);
    expect(out.centsOffset, closeTo(-12, 0.01));
  });

  test('short gaps hold the note; long gaps release it', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    expect(feed(s, null, 3)?.midiNumber, 69); // hold
    expect(s.process(n(69))?.midiNumber, 69);
    expect(feed(s, null, 10), isNull); // released
    expect(s.process(n(69)), isNull); // must re-confirm
    expect(s.process(n(69))?.midiNumber, 69);
  });

  test('after release a different note needs only the normal confirmation', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    feed(s, null, 10);
    feed(s, n(81), 1);
    expect(s.process(n(81))?.midiNumber, 81); // octave rule is not applied
  });

  test('reset clears everything', () {
    final s = NoteStabilizer();
    feed(s, n(69), 8);
    s.reset();
    expect(s.process(n(69)), isNull);
  });
}
