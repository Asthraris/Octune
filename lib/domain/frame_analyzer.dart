import 'dart:typed_data';

import 'analysis_snapshot.dart';
import 'detector_settings.dart';

/// What the application layer needs from the DSP pipeline. Lets the
/// application layer stay independent of the concrete engine classes.
abstract interface class FrameAnalyzer {
  /// Analyses one fixed-size frame of mono samples.
  AnalysisSnapshot process(Float32List frame, int sampleRate, int timestampMs);

  /// Applies new settings immediately.
  void updateSettings(DetectorSettings settings);

  /// Moves the noise-gate threshold to [db] (UI drag). Returns the
  /// equivalent 0..1 noiseGate value, already applied.
  double setGateThresholdDb(double db);

  /// Clears all adaptive state (noise floor, held notes, decays).
  void reset();
}
