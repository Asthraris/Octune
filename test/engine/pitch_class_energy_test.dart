import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/pitch_class_energy.dart';
import 'package:octune/engine/spectrum_analyzer.dart';

import '../helpers/signals.dart';

const double dt = 23.2;

void main() {
  final analyzer = SpectrumAnalyzer();

  int argmax(List<double> v) {
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  test('a C4 sine lights pitch class C (index 0) most', () {
    final e = PitchClassEnergy();
    final peaks = analyzer.analyze(sine(261.63), kSampleRate).peaks;
    final out = e.update(peaks, dt);
    expect(out.length, 12);
    expect(argmax(out), 0);
    expect(out[0], closeTo(1, 1e-6));
    for (var i = 1; i < 12; i++) {
      expect(out[i], lessThan(0.05), reason: 'class $i');
    }
  });

  test('other notes land in their own class', () {
    final expected = {440.0: 9, 329.63: 4, 466.16: 10, 392.0: 7};
    for (final entry in expected.entries) {
      final e = PitchClassEnergy();
      final peaks = analyzer.analyze(sine(entry.key), kSampleRate).peaks;
      expect(argmax(e.update(peaks, dt)), entry.value, reason: '${entry.key}');
    }
  });

  test('energy decays smoothly after the tone stops', () {
    final e = PitchClassEnergy();
    final peaks = analyzer.analyze(sine(261.63), kSampleRate).peaks;
    e.update(peaks, dt);
    var previous = 1.0;
    var t = 0.0;
    double value = 1;
    while (t < 1000) {
      value = e.update(const [], dt)[0];
      expect(value, lessThanOrEqualTo(previous));
      previous = value;
      t += dt;
    }
    expect(value, lessThan(0.06)); // ~1 s later
  });

  test('about 37% remains after one time constant (300 ms)', () {
    final e = PitchClassEnergy();
    e.update(analyzer.analyze(sine(261.63), kSampleRate).peaks, dt);
    var v = 0.0;
    for (var t = 0.0; t < 300; t += dt) {
      v = e.update(const [], dt)[0];
    }
    expect(v, inInclusiveRange(0.3, 0.45));
  });

  test('a note below the noise floor does not light the ring', () {
    final e = PitchClassEnergy();
    final r = analyzer.analyze(sine(261.63, amp: 0.001), kSampleRate,
        noiseFloorDb: -90);
    // loud relative to -90 dB, so presence is 1 ...
    expect(e.update(r.peaks, dt, noiseFloorDb: -90)[0], greaterThan(0.9));
    // ... but near a higher noise floor, presence (and brightness) drops.
    final e2 = PitchClassEnergy();
    expect(e2.update(r.peaks, dt, noiseFloorDb: -64)[0], lessThan(0.5));
  });

  test('two notes both light up', () {
    final a = sine(261.63, amp: 0.3);
    final b = sine(392.0, amp: 0.3);
    for (var i = 0; i < a.length; i++) {
      a[i] += b[i];
    }
    final out = PitchClassEnergy()
        .update(analyzer.analyze(a, kSampleRate).peaks, dt);
    expect(out[0], greaterThan(0.8)); // C
    expect(out[7], greaterThan(0.8)); // G
  });

  test('reset clears energy', () {
    final e = PitchClassEnergy();
    e.update(analyzer.analyze(sine(261.63), kSampleRate).peaks, dt);
    e.reset();
    expect(e.update(const [], dt).every((v) => v == 0), isTrue);
  });
}
