import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_math.dart';
import 'package:octune/engine/pitch_analysis.dart';
import 'package:octune/engine/pitch_estimate.dart';
import 'package:octune/engine/yin_pitch_detector.dart';

const int _sampleRate = 44100;

void main() {
  final YinPitchDetector detector = YinPitchDetector(
    minHz: 70,
    maxHz: 2000,
  );

  PitchEstimate? estimate(Float32List samples) {
    return detector.analyze(samples, _sampleRate).estimate;
  }

  test('sines within 0.5% at 44.1 kHz', () {
    const List<double> frequencies = <double>[
      82.4,
      110,
      220,
      440,
      880,
      1318,
    ];
    for (final double hz in frequencies) {
      final PitchEstimate? got = estimate(_sine(hz));
      expect(got, isNotNull, reason: '$hz Hz returned null');
      final double error = (got!.frequencyHz - hz).abs() / hz;
      expect(
        error,
        lessThan(0.005),
        reason: '$hz Hz -> ${got.frequencyHz} Hz (${error * 100}%)',
      );
    }
  });

  test('harmonic series returns the fundamental, not an octave up', () {
    const double f0 = 220;
    final Float32List samples = _harmonicTone(
      f0,
      amplitudes: const <double>[1, 0.5, 0.33],
    );
    final PitchEstimate? got = estimate(samples);
    expect(got, isNotNull);
    expect((got!.frequencyHz - f0).abs() / f0, lessThan(0.005));
    expect(got.frequencyHz, lessThan(f0 * 1.5));
  });

  test('silence returns null estimate', () {
    expect(estimate(Float32List(2048)), isNull);
  });

  test('white noise returns null estimate', () {
    expect(estimate(_whiteNoise(seed: 1)), isNull);
    expect(estimate(_whiteNoise(seed: 2)), isNull);
    expect(estimate(_whiteNoise(seed: 3)), isNull);
  });

  test('salience peaks in the correct semitone bin', () {
    const double hz = 440;
    final PitchAnalysis analysis = detector.analyze(_sine(hz), _sampleRate);
    expect(analysis.estimate, isNotNull);
    var peakBin = 0;
    var peak = analysis.salienceBySemitone[0];
    for (var i = 1; i < analysis.salienceBySemitone.length; i++) {
      if (analysis.salienceBySemitone[i] > peak) {
        peak = analysis.salienceBySemitone[i];
        peakBin = i;
      }
    }
    final int peakMidi = analysis.salienceLowestMidi + peakBin;
    expect(peakMidi, frequencyToMidi(hz).round());
  });

  test('benchmark ms per frame', () {
    final Float32List samples = _sine(440);
    const int frames = 40;
    detector.analyze(samples, _sampleRate);
    final Stopwatch watch = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      detector.analyze(samples, _sampleRate);
    }
    watch.stop();
    final double msPerFrame = watch.elapsedMicroseconds / frames / 1000;
    stdout.writeln('YIN ms/frame: ${msPerFrame.toStringAsFixed(3)}');
    expect(msPerFrame, greaterThan(0));
  });
}

Float32List _sine(double hz, {int length = 2048}) {
  final Float32List out = Float32List(length);
  final double step = 2 * math.pi * hz / _sampleRate;
  for (var i = 0; i < length; i++) {
    out[i] = math.sin(step * i);
  }
  return out;
}

Float32List _harmonicTone(
  double f0, {
  required List<double> amplitudes,
  int length = 2048,
}) {
  final Float32List out = Float32List(length);
  for (var h = 0; h < amplitudes.length; h++) {
    final double step = 2 * math.pi * f0 * (h + 1) / _sampleRate;
    final double amp = amplitudes[h];
    for (var i = 0; i < length; i++) {
      out[i] += amp * math.sin(step * i);
    }
  }
  var peak = 0.0;
  for (var i = 0; i < length; i++) {
    peak = math.max(peak, out[i].abs());
  }
  if (peak > 0) {
    for (var i = 0; i < length; i++) {
      out[i] /= peak;
    }
  }
  return out;
}

Float32List _whiteNoise({required int seed, int length = 2048}) {
  final math.Random rng = math.Random(seed);
  final Float32List out = Float32List(length);
  for (var i = 0; i < length; i++) {
    out[i] = rng.nextDouble() * 2 - 1;
  }
  return out;
}
