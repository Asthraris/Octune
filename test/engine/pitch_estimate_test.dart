import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/pitch_estimate.dart';

void main() {
  test('equality', () {
    const PitchEstimate a = PitchEstimate(frequencyHz: 440, clarity: 0.9);
    const PitchEstimate b = PitchEstimate(frequencyHz: 440, clarity: 0.9);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
