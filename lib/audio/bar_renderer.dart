import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/metronome_settings.dart';

/// One bar of clicks as audio, meant to be looped by a native player.
class RenderedBar {
  const RenderedBar({
    required this.samples,
    required this.sampleRate,
    required this.beatStartSamples,
  });

  final Float32List samples;
  final int sampleRate;

  /// Sample index where each beat of the bar starts.
  final List<int> beatStartSamples;

  int get length => samples.length;
  double get durationMs => samples.length * 1000 / sampleRate;
}

/// Renders a looping bar with sample-exact click placement.
///
/// Why a looped buffer instead of timers: the native audio thread plays it
/// with the hardware clock, so UI jank, garbage collection or a busy event
/// loop cannot make a click late. Drift comes only from rounding the bar
/// length to whole samples (< 0.5 sample per bar, about 0.01 ms).
class BarRenderer {
  static const double accentHz = 1600;
  static const double beatHz = 1000;
  static const double subHz = 800;
  static const double accentAmp = 0.95;
  static const double beatAmp = 0.75;
  static const double subAmp = 0.4;

  static RenderedBar render(MetronomeSettings settings, {int sampleRate = 44100}) {
    final s = settings.validated();
    final beatExact = sampleRate * 60.0 / s.bpm;
    final barLength = math.max(1, (beatExact * s.beatsPerBar).round());
    final out = Float32List(barLength);

    final accent = click(accentHz, accentAmp, sampleRate);
    final normal = click(beatHz, beatAmp, sampleRate);
    final sub = click(subHz, subAmp, sampleRate);

    final beatStarts = <int>[];
    for (var b = 0; b < s.beatsPerBar; b++) {
      beatStarts.add((b * beatExact).round() % barLength);
      for (var j = 0; j < s.subdivision; j++) {
        final start = ((b + j / s.subdivision) * beatExact).round();
        final Float32List shape =
            j > 0 ? sub : (b == 0 && s.accentFirstBeat ? accent : normal);
        for (var k = 0; k < shape.length; k++) {
          out[(start + k) % barLength] += shape[k]; // wraps, so the loop is seamless
        }
      }
    }
    for (var i = 0; i < out.length; i++) {
      if (out[i] > 1) out[i] = 1;
      if (out[i] < -1) out[i] = -1;
    }
    return RenderedBar(samples: out, sampleRate: sampleRate, beatStartSamples: beatStarts);
  }

  /// A short decaying sine burst with a 1 ms attack (no click-on-click pop).
  static Float32List click(
    double hz,
    double amp,
    int sampleRate, {
    double durationMs = 35,
  }) {
    final n = (durationMs * sampleRate / 1000).round();
    final out = Float32List(n);
    final attack = math.max(1, (0.001 * sampleRate).round());
    final decay = 0.008 * sampleRate; // time constant 8 ms
    for (var k = 0; k < n; k++) {
      final env = math.min(1.0, k / attack) * math.exp(-k / decay);
      out[k] = amp * env * math.sin(2 * math.pi * hz * k / sampleRate);
    }
    return out;
  }
}
