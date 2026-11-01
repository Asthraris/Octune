import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/analysis_snapshot.dart';
import 'package:octune/domain/detector_settings.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/engine/pitch_pipeline.dart';

import '../helpers/signals.dart';

List<AnalysisSnapshot> run(PitchPipeline p, Float32List signal) {
  final out = <AnalysisSnapshot>[];
  final fs = frames(signal);
  for (var i = 0; i < fs.length; i++) {
    out.add(p.process(fs[i], kSampleRate, timestampMs(i)));
  }
  return out;
}

String? label(AnalysisSnapshot s) {
  final e = s.stableNote;
  return e == null ? null : '${e.noteName.asciiName}${e.octave}';
}

/// Collapses consecutive duplicates: [null, A4, A4, C5] -> [null, A4, C5].
List<String?> collapse(List<AnalysisSnapshot> snaps) {
  final out = <String?>[];
  for (final s in snaps) {
    final l = label(s);
    if (out.isEmpty || out.last != l) out.add(l);
  }
  return out;
}

void main() {
  test('A4 -> C5 -> silence -> E4 yields exactly those notes, nothing in the gap',
      () {
    final p = PitchPipeline.standard();
    final signal = render(const [
      Segment(0, 0.5),
      Segment(440, 0.6),
      Segment(523.25, 0.6),
      Segment(0, 0.7),
      Segment(329.63, 0.6),
      Segment(0, 0.6),
    ]);
    final snaps = run(p, signal);
    expect(collapse(snaps), equals([null, 'A4', 'C5', null, 'E4', null]));
  });

  test('stable notes are accurate in cents on clean tones', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, render(const [Segment(0, 0.4), Segment(440, 1.0)]));
    final last = snaps.last.stableNote!;
    expect(last.cents.abs(), lessThan(3));
    expect(last.conf, greaterThan(0.9));
    expect(snaps.last.detectedHz!, closeTo(440, 1));
  });

  test('a sharp note reports positive cents', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, render(const [Segment(0, 0.4), Segment(450.0, 1.0)]));
    final e = snaps.last.stableNote!;
    expect('${e.noteName.asciiName}${e.octave}', 'A4');
    expect(e.cents, closeTo(38.9, 4)); // 450 Hz is +38.9 cents above A4
  });

  test('tone present from the first frame is still detected', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, render(const [Segment(440, 1.2)]));
    expect(label(snaps.last), 'A4');
  });

  test('white noise produces no notes (constant from start)', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, whiteNoise(n: kSampleRate * 4, amp: 0.1));
    expect(snaps.where((s) => s.stableNote != null), isEmpty);
  });

  test('white noise after silence produces no notes', () {
    final p = PitchPipeline.standard();
    final signal = concat([
      render(const [Segment(0, 0.6)]),
      whiteNoise(n: kSampleRate * 4, amp: 0.2, seed: 5),
    ]);
    final snaps = run(p, signal);
    expect(snaps.where((s) => s.stableNote != null), isEmpty);
  });

  test('low-level background noise under a tone does not break detection', () {
    final p = PitchPipeline.standard();
    final signal = addNoise(
      render(const [Segment(0, 0.5), Segment(440, 1.0), Segment(0, 0.8)]),
      0.01,
    );
    final snaps = run(p, signal);
    expect(collapse(snaps), equals([null, 'A4', null]));
  });

  test('+/-30 cent vibrato does not change the note name', () {
    final p = PitchPipeline.standard();
    final signal = concat([
      render(const [Segment(0, 0.4)]),
      vibratoTone(261.63, 3.0),
    ]);
    final snaps = run(p, signal);
    final labels = snaps.map(label).whereType<String>().toSet();
    expect(labels, equals({'C4'}));
  });

  test('guitar-like harmonic tones keep the right octave', () {
    final p = PitchPipeline.standard();
    final parts = <Float32List>[
      render(const [Segment(0, 0.4)]),
      for (final f in [110.0, 164.81, 220.0])
        harmonicTone(f, [1, .7, .5, .35, .2], n: (0.7 * kSampleRate).round()),
      render(const [Segment(0, 0.6)]),
    ];
    final snaps = run(p, concat(parts));
    expect(collapse(snaps), equals([null, 'A2', 'E3', 'A3', null]));
  });

  test('snapshot fields for the UI are populated', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, render(const [Segment(0, 0.4), Segment(261.63, 0.8)]));
    final s = snaps.last;
    expect(s.gateOpen, isTrue);
    expect(s.amplitudeDb, closeTo(-13.5, 1)); // 0.3 amp sine
    expect(s.amplitudeLinear, closeTo(0.212, 0.01));
    expect(s.gateThresholdDb, greaterThan(s.noiseFloorDb));
    expect(s.spectrum.magnitudesDb.length, 64);
    expect(s.spectrum.peakHz!, closeTo(261.63, 1.5));
    expect(s.pitchClassEnergy.length, 12);
    expect(s.pitchClassEnergy[0], greaterThan(0.9));
    expect(s.salienceBySemitone.length, greaterThan(40));
    var best = 0;
    for (var i = 1; i < s.salienceBySemitone.length; i++) {
      if (s.salienceBySemitone[i] > s.salienceBySemitone[best]) best = i;
    }
    expect(s.salienceLowestMidi + best, 60);
  });

  test('silence snapshot has zero salience and a closed gate', () {
    final p = PitchPipeline.standard();
    final snaps = run(p, render(const [Segment(0, 1.0)]));
    final s = snaps.last;
    expect(s.gateOpen, isFalse);
    expect(s.stableNote, isNull);
    expect(s.detectedHz, isNull);
    expect(s.salienceBySemitone.every((v) => v == 0), isTrue);
    expect(s.pitchClassEnergy.every((v) => v == 0), isTrue);
    expect(s.spectrum.peakHz, isNull);
  });

  test('settings update live: A4 reference changes the reported note', () {
    final p = PitchPipeline.standard();
    final signal = render(const [Segment(0, 0.4), Segment(440, 1.0)]);
    expect(label(run(p, signal).last), 'A4');

    final p2 = PitchPipeline.standard(
        settings: const DetectorSettings(a4Hz: 415));
    final e = run(p2, signal).last.stableNote!;
    // 440 Hz against A4 = 415 is ~ +99 cents above A4 => A#4 at about -1 cent
    expect('${e.noteName.asciiName}${e.octave}', 'A#4');
  });

  test('a stricter confidence setting rejects a noisy tone', () {
    final noisy = addNoise(
      render(const [Segment(0, 0.4), Segment(440, 1.0)]),
      0.25,
      seed: 11,
    );
    final loose = PitchPipeline.standard(
        settings: const DetectorSettings(minConfidence: 0.8));
    final strict = PitchPipeline.standard(
        settings: const DetectorSettings(minConfidence: 0.99));
    final looseNotes =
        run(loose, noisy).where((s) => s.stableNote != null).length;
    final strictNotes =
        run(strict, noisy).where((s) => s.stableNote != null).length;
    expect(strictNotes, lessThanOrEqualTo(looseNotes));
    expect(strictNotes, 0);
  });

  test('narrowing the range changes the salience shape live', () {
    final p = PitchPipeline.standard();
    final before = run(p, render(const [Segment(0, 0.3)])).last;
    p.updateSettings(const DetectorSettings(
        minFrequencyHz: 150, maxFrequencyHz: 700));
    final after = run(p, render(const [Segment(0, 0.3)])).last;
    expect(after.salienceBySemitone.length,
        lessThan(before.salienceBySemitone.length));
  });

  test('dragging the gate threshold changes behaviour live', () {
    // Quiet room (about -50 dBFS) then a soft tone (about -33 dBFS).
    Float32List room(double seconds) =>
        whiteNoise(n: (seconds * kSampleRate).round(), amp: 0.00548);
    final tone = render(const [Segment(440, 1.0, amp: 0.03)]);

    final normal = PitchPipeline.standard();
    run(normal, room(0.6));
    expect(run(normal, tone).last.gateOpen, isTrue); // default passes it

    final strict = PitchPipeline.standard();
    run(strict, room(0.6));
    strict.setGateThresholdDb(strict.noiseFloorDb + 24); // strictest margin
    final snaps = run(strict, tone);
    expect(snaps.every((s) => !s.gateOpen), isTrue);
    expect(snaps.every((s) => s.stableNote == null), isTrue);
    expect(strict.settings.noiseGate, closeTo(1, 1e-9));
  });

  test('benchmark: full pipeline ms per frame', () {
    final p = PitchPipeline.standard();
    final fs = frames(render(const [Segment(0, 0.3), Segment(440, 1.5)]));
    for (var i = 0; i < 20; i++) {
      p.process(fs[i], kSampleRate, timestampMs(i));
    }
    final sw = Stopwatch()..start();
    var count = 0;
    for (var i = 20; i < fs.length; i++) {
      p.process(fs[i], kSampleRate, timestampMs(i));
      count++;
    }
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000 / count;
    // ignore: avoid_print
    print('        pipeline: ${ms.toStringAsFixed(2)} ms/frame '
        '(hop budget ${(kHop * 1000 / kSampleRate).toStringAsFixed(1)} ms)');
    expect(ms, lessThan(kHop * 1000 / kSampleRate / 2));
  });
}
