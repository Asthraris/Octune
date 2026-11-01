import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/pitch_analysis.dart';
import 'package:octune/engine/pitch_estimate.dart';

void main() {
  test('copies salience', () {
    final Float32List bins = Float32List.fromList(<double>[0.1, 0.9]);
    final PitchAnalysis analysis = PitchAnalysis(
      estimate: const PitchEstimate(frequencyHz: 440, clarity: 0.95),
      salienceBySemitone: bins,
      salienceLowestMidi: 60,
    );
    bins[1] = 0;
    expect(analysis.salienceBySemitone[1], closeTo(0.9, 1e-5));
    expect(analysis.estimate?.frequencyHz, 440);
    expect(analysis.salienceLowestMidi, 60);
  });
}
