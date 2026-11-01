import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/yin_pitch_detector.dart';

import '../helpers/signals.dart';

void main() {
  group('YinPitchDetector accuracy', () {
    for (final f in [82.41, 110.0, 220.0, 440.0, 880.0, 1318.51]) {
      test('pure sine $f Hz within 0.5%', () {
        final d = YinPitchDetector();
        final est = d.analyze(sine(f), kSampleRate).estimate;
        expect(est, isNotNull);
        expect((est!.frequencyHz - f).abs() / f, lessThan(0.005));
        expect(est.clarity, greaterThan(0.9));
      });
    }

    test('arbitrary phase does not matter', () {
      final d = YinPitchDetector();
      for (final p in [0.0, 1.0, 2.5, 4.0]) {
        final est = d.analyze(sine(330, phase: p), kSampleRate).estimate;
        expect(est, isNotNull);
        expect((est!.frequencyHz - 330).abs() / 330, lessThan(0.005));
      }
    });
  });

  group('YinPitchDetector harmonics', () {
    test('guitar-like spectrum returns the fundamental, not an octave up', () {
      final d = YinPitchDetector();
      for (final f in [110.0, 196.0, 329.63]) {
        final est = d
            .analyze(harmonicTone(f, [1, 0.8, 0.6, 0.4, 0.3]), kSampleRate)
            .estimate;
        expect(est, isNotNull, reason: '$f');
        expect((est!.frequencyHz - f).abs() / f, lessThan(0.005), reason: '$f');
      }
    });

    test('moderately strong 2nd harmonic still gives the fundamental', () {
      final d = YinPitchDetector();
      final est =
          d.analyze(harmonicTone(220, [0.5, 1.0]), kSampleRate).estimate;
      expect(est, isNotNull);
      expect((est!.frequencyHz - 220).abs() / 220, lessThan(0.005));
    });

    test('weak fundamental (0.2 vs 1.0): documented behaviour', () {
      // KNOWN LIMIT: when the fundamental is much weaker than the 2nd
      // harmonic, YIN may legitimately report the octave above. Both answers
      // are acceptable here; the NoteStabilizer's octave check is the defence.
      final d = YinPitchDetector();
      final est =
          d.analyze(harmonicTone(220, [0.2, 1.0]), kSampleRate).estimate;
      expect(est, isNotNull);
      final f = est!.frequencyHz;
      final nearF0 = (f - 220).abs() / 220 < 0.005;
      final nearOctave = (f - 440).abs() / 440 < 0.005;
      expect(nearF0 || nearOctave, isTrue, reason: 'got $f');
      // ignore: avoid_print
      print('        (weak-fundamental case returned ${f.toStringAsFixed(1)} Hz)');
    });
  });

  group('YinPitchDetector rejection', () {
    test('silence gives no estimate and zero salience', () {
      final d = YinPitchDetector();
      final a = d.analyze(silence(), kSampleRate);
      expect(a.estimate, isNull);
      expect(a.salienceBySemitone.every((v) => v == 0), isTrue);
    });

    test('white noise gives no estimate', () {
      final d = YinPitchDetector();
      for (var seed = 1; seed <= 10; seed++) {
        final a = d.analyze(whiteNoise(seed: seed), kSampleRate);
        expect(a.estimate, isNull, reason: 'seed $seed');
      }
    });

    test('short frame gives an empty analysis, not a crash', () {
      final d = YinPitchDetector();
      final a = d.analyze(sine(440, n: 512), kSampleRate);
      expect(a.estimate, isNull);
      expect(a.salienceBySemitone.length, greaterThan(0));
    });
  });

  group('YinPitchDetector salience', () {
    test('peaks in the correct semitone bin', () {
      final d = YinPitchDetector();
      for (final entry in {440.0: 69, 220.0: 57, 523.25: 72, 130.81: 48}.entries) {
        final a = d.analyze(sine(entry.key), kSampleRate);
        var best = 0;
        for (var i = 1; i < a.salienceBySemitone.length; i++) {
          if (a.salienceBySemitone[i] > a.salienceBySemitone[best]) best = i;
        }
        expect(a.salienceLowestMidi + best, entry.value, reason: '${entry.key}');
      }
    });

    test('values stay within 0..1', () {
      final d = YinPitchDetector();
      final a = d.analyze(harmonicTone(196, [1, .5, .3]), kSampleRate);
      for (final v in a.salienceBySemitone) {
        expect(v, inInclusiveRange(0, 1));
      }
    });

    test('emptyAnalysis has the same shape as a real analysis', () {
      final d = YinPitchDetector();
      final real = d.analyze(sine(440), kSampleRate);
      final empty = d.emptyAnalysis(kSampleRate);
      expect(empty.salienceBySemitone.length, real.salienceBySemitone.length);
      expect(empty.salienceLowestMidi, real.salienceLowestMidi);
      expect(empty.estimate, isNull);
    });

    test('setFrequencyRange changes the salience range', () {
      final d = YinPitchDetector();
      final wide = d.emptyAnalysis(kSampleRate);
      d.setFrequencyRange(150, 700);
      final narrow = d.emptyAnalysis(kSampleRate);
      expect(narrow.salienceBySemitone.length,
          lessThan(wide.salienceBySemitone.length));
      expect(narrow.salienceLowestMidi, greaterThan(wide.salienceLowestMidi));
    });

    test('requested minimum below the window limit is clamped', () {
      final d = YinPitchDetector(minHz: 30);
      d.emptyAnalysis(kSampleRate);
      expect(d.effectiveMinHz, closeTo(kSampleRate / 1024, 0.5));
    });
  });

  test('benchmark: ms per 2048-sample frame', () {
    final d = YinPitchDetector();
    final frame = harmonicTone(196, [1, .5, .3]);
    d.analyze(frame, kSampleRate); // warm up
    const iterations = 200;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      d.analyze(frame, kSampleRate);
    }
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000 / iterations;
    // ignore: avoid_print
    print('        YIN: ${ms.toStringAsFixed(2)} ms/frame '
        '(hop budget ${(kHop * 1000 / kSampleRate).toStringAsFixed(1)} ms)');
    expect(ms, lessThan(math.max(1, kHop * 1000 / kSampleRate)));
  });
}
