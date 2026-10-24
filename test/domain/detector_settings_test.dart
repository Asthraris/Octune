import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/detector_settings.dart';

void main() {
  test('defaults', () {
    final DetectorSettings settings = DetectorSettings();
    expect(settings.a4Hz, 440);
    expect(settings.noiseGate, 0);
    expect(settings.minConfidence, 0);
    expect(settings.minFrequencyHz, 65);
    expect(settings.maxFrequencyHz, 2100);
  });

  test('clamps a4, gate, and confidence', () {
    final DetectorSettings low = DetectorSettings(
      a4Hz: 400,
      noiseGate: -0.5,
      minConfidence: -1,
    );
    expect(low.a4Hz, 415);
    expect(low.noiseGate, 0);
    expect(low.minConfidence, 0);

    final DetectorSettings high = DetectorSettings(
      a4Hz: 500,
      noiseGate: 2,
      minConfidence: 1.5,
    );
    expect(high.a4Hz, 466);
    expect(high.noiseGate, 1);
    expect(high.minConfidence, 1);
  });

  test('swaps inverted frequency range', () {
    final DetectorSettings settings = DetectorSettings(
      minFrequencyHz: 2000,
      maxFrequencyHz: 80,
    );
    expect(settings.minFrequencyHz, 80);
    expect(settings.maxFrequencyHz, 2000);
  });
}
