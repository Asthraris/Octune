import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/noise_gate.dart';

const double dt = 23.2; // ms per frame (hop 1024 @ 44.1 kHz)

/// Feeds [frames] frames of [level] and returns the final open state.
bool feed(NoiseGate g, double level, int frames, {bool pitched = true}) {
  var open = false;
  for (var i = 0; i < frames; i++) {
    open = g.process(level, dt, pitched: pitched);
  }
  return open;
}

void main() {
  test('silence stays closed', () {
    final g = NoiseGate();
    for (var i = 0; i < 100; i++) {
      expect(g.process(-90, dt), isFalse);
    }
  });

  test('step from silence to tone opens the gate immediately', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    expect(g.process(-20, dt), isTrue);
  });

  test('tone present from the very first frame still opens', () {
    final g = NoiseGate();
    expect(g.process(-14, dt), isTrue);
    expect(feed(g, -14, 100), isTrue);
  });

  test('constant background noise raises the floor and stays closed', () {
    final g = NoiseGate();
    var opened = false;
    for (var i = 0; i < 300; i++) {
      final jitter = (i % 5 - 2) * 0.75; // +/-1.5 dB
      if (g.process(-50 + jitter, dt)) opened = true;
    }
    expect(opened, isFalse);
    expect(g.noiseFloorDb, closeTo(-50, 3));
    expect(g.thresholdDb, greaterThan(-48.5));
  });

  test('a tone above that background noise still opens', () {
    final g = NoiseGate();
    feed(g, -50, 100);
    expect(g.process(-25, dt), isTrue);
  });

  test('hold time prevents chatter', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    feed(g, -20, 10);
    expect(g.isOpen, isTrue);
    expect(feed(g, -90, 5), isTrue); // 116 ms < 150 ms hold
    expect(feed(g, -90, 3), isFalse); // now past the hold
  });

  test('level just under the threshold does not close (hysteresis)', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    feed(g, -20, 10);
    final thr = g.thresholdDb;
    expect(feed(g, thr - 1.5, 30), isTrue);
  });

  test('unpitched noise that opened the gate is eventually absorbed', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    expect(g.process(-45, dt, pitched: false), isTrue);
    expect(feed(g, -45, 430, pitched: false), isFalse); // ~10 s
  });

  test('a long pitched note does not close the gate', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    expect(feed(g, -20, 430, pitched: true), isTrue); // ~10 s
  });

  test('floor is capped so a loud tone at start cannot lock the gate', () {
    final g = NoiseGate();
    feed(g, -10, 60);
    expect(g.noiseFloorDb, lessThanOrEqualTo(-45));
  });

  test('threshold never drops below the absolute minimum', () {
    final g = NoiseGate();
    feed(g, -90, 30);
    expect(g.thresholdDb, greaterThanOrEqualTo(-65));
  });

  test('noiseGate setting widens the margin', () {
    final lo = NoiseGate(noiseGate: 0);
    final hi = NoiseGate(noiseGate: 1);
    feed(lo, -50, 30);
    feed(hi, -50, 30);
    expect(hi.thresholdDb - hi.noiseFloorDb, closeTo(24, 1e-6));
    expect(lo.thresholdDb - lo.noiseFloorDb, closeTo(4, 1e-6));
  });

  test('setThresholdDb round trip', () {
    final g = NoiseGate();
    feed(g, -50, 30);
    final setting = g.setThresholdDb(g.noiseFloorDb + 12);
    expect(setting, closeTo(0.4, 1e-6));
    expect(g.thresholdDb - g.noiseFloorDb, closeTo(12, 1e-6));
    expect(g.setThresholdDb(g.noiseFloorDb - 10), 0); // below floor: most sensitive
    expect(g.setThresholdDb(0), 1); // far above floor: strictest
  });

  test('reset restarts calibration', () {
    final g = NoiseGate();
    feed(g, -20, 30);
    g.reset();
    expect(g.isOpen, isFalse);
    expect(g.noiseFloorDb, -90);
  });
}
