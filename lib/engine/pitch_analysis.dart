import 'dart:typed_data';

import 'pitch_estimate.dart';

final class PitchAnalysis {
  PitchAnalysis({
    required this.estimate,
    required Float32List salienceBySemitone,
    required this.salienceLowestMidi,
  }) : salienceBySemitone = Float32List.fromList(salienceBySemitone);

  final PitchEstimate? estimate;
  final Float32List salienceBySemitone;
  final int salienceLowestMidi;
}
