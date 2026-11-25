import 'dart:math' as math;
import 'dart:typed_data';

/// A short melody with gaps and a little room noise, for demos and tests on
/// machines without a microphone. About 5 seconds, mono.
Float32List demoMelody({int sampleRate = 44100}) {
  const notes = [220.0, 261.63, 329.63, 392.0, 440.0, 523.25];
  final noteSamples = (0.5 * sampleRate).round();
  final gapSamples = (0.3 * sampleRate).round();
  final out = Float32List(notes.length * (noteSamples + gapSamples));
  final rnd = math.Random(3);
  var o = 0;
  for (final f in notes) {
    for (var i = 0; i < noteSamples; i++) {
      final t = i / sampleRate;
      final env = math.min(1.0, i / 400) * math.min(1.0, (noteSamples - i) / 400);
      out[o++] = env *
          0.3 *
          (math.sin(2 * math.pi * f * t) +
              0.4 * math.sin(2 * math.pi * 2 * f * t) +
              0.2 * math.sin(2 * math.pi * 3 * f * t)) /
          1.6;
    }
    for (var i = 0; i < gapSamples; i++) {
      out[o++] = 0.002 * (rnd.nextDouble() * 2 - 1);
    }
  }
  return out;
}
