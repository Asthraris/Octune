import 'dart:typed_data';

import 'pitch_analysis.dart';

abstract interface class PitchDetector {
  PitchAnalysis analyze(Float32List samples, int sampleRate);
}
