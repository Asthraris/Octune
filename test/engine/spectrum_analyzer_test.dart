import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/spectrum_analyzer.dart';

import '../helpers/signals.dart';

void main() {
  final analyzer = SpectrumAnalyzer();

  test('440 Hz sine peaks at 440 Hz within 1 Hz and about -6 dB', () {
    final r = analyzer.analyze(sine(440, amp: 0.5), kSampleRate);
    expect(r.view.peakHz, isNotNull);
    expect(r.view.peakHz!, closeTo(440, 1));
    expect(r.view.peakDb, closeTo(-6.02, 1));
  });

  test('peak accuracy across the range and across bin offsets', () {
    for (final f in [98.0, 196.0, 261.63, 329.63, 523.25, 1000.0, 1760.0, 3000.0]) {
      final r = analyzer.analyze(sine(f), kSampleRate);
      expect(r.view.peakHz!, closeTo(f, 1.5), reason: '$f Hz');
    }
  });

  test('two tones: the louder one is the peak, both are listed', () {
    final a = sine(440, amp: 0.5);
    final b = sine(1000, amp: 0.1);
    for (var i = 0; i < a.length; i++) {
      a[i] += b[i];
    }
    final r = analyzer.analyze(a, kSampleRate);
    expect(r.view.peakHz!, closeTo(440, 1));
    expect(r.peaks.length, greaterThanOrEqualTo(2));
    expect(r.peaks.any((p) => (p.frequencyHz - 1000).abs() < 2), isTrue);
  });

  test('view has the configured number of log bins and covers the range', () {
    final r = analyzer.analyze(sine(440), kSampleRate);
    expect(r.view.magnitudesDb.length, 64);
    expect(r.view.minHz, 50);
    expect(r.view.maxHz, 4000);
    // the bin containing 440 Hz should be among the strongest
    var best = 0;
    for (var i = 1; i < 64; i++) {
      if (r.view.magnitudesDb[i] > r.view.magnitudesDb[best]) best = i;
    }
    // expected bin index for 440 Hz on a log axis from 50 to 4000 Hz
    final expected = (64 * math.log(440 / 50) / math.log(80)).floor();
    expect((best - expected).abs(), lessThanOrEqualTo(1));
  });

  test('noise at the floor level gives a null peak', () {
    // white noise of peak 0.0045 is about -57 dBFS RMS
    final noise = whiteNoise(amp: 0.0045);
    final r = analyzer.analyze(noise, kSampleRate, noiseFloorDb: -57);
    expect(r.view.peakHz, isNull);
    expect(r.peaks, isEmpty);
  });

  test('a tone 25 dB above the floor is found', () {
    final r = analyzer.analyze(sine(440, amp: 0.1), kSampleRate,
        noiseFloorDb: -50);
    expect(r.view.peakHz, isNotNull);
  });

  test('silence gives no peaks and does not crash', () {
    final r = analyzer.analyze(silence(), kSampleRate);
    expect(r.view.peakHz, isNull);
    expect(r.peaks, isEmpty);
  });

  test('benchmark: ms per frame', () {
    final frame = sine(440);
    analyzer.analyze(frame, kSampleRate);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      analyzer.analyze(frame, kSampleRate);
    }
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000 / 200;
    // ignore: avoid_print
    print('        spectrum: ${ms.toStringAsFixed(2)} ms/frame');
    expect(ms, lessThan(10));
  });
}
