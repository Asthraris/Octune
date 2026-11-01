import 'dart:math' as math;
import 'dart:typed_data';

const int kSampleRate = 44100;
const int kFrameSize = 2048;
const int kHop = 1024;

/// Pure sine of [hz].
Float32List sine(
  double hz, {
  int n = kFrameSize,
  int sampleRate = kSampleRate,
  double amp = 0.5,
  double phase = 0,
}) {
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * hz * i / sampleRate + phase);
  }
  return out;
}

/// Fundamental plus harmonics; [amps] are the amplitudes of harmonics 1, 2, 3...
Float32List harmonicTone(
  double f0,
  List<double> amps, {
  int n = kFrameSize,
  int sampleRate = kSampleRate,
}) {
  final out = Float32List(n);
  for (var h = 0; h < amps.length; h++) {
    final f = f0 * (h + 1);
    for (var i = 0; i < n; i++) {
      out[i] += amps[h] * math.sin(2 * math.pi * f * i / sampleRate);
    }
  }
  return out;
}

Float32List silence([int n = kFrameSize]) => Float32List(n);

/// Deterministic white noise with the given peak amplitude.
Float32List whiteNoise({int n = kFrameSize, double amp = 0.3, int seed = 1}) {
  final rnd = math.Random(seed);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * (rnd.nextDouble() * 2 - 1);
  }
  return out;
}

/// One steady segment of a rendered melody. [hz] <= 0 is silence.
class Segment {
  const Segment(this.hz, this.seconds, {this.amp = 0.3});
  final double hz;
  final double seconds;
  final double amp;
}

/// Phase-continuous within a segment.
Float32List render(List<Segment> segments, {int sampleRate = kSampleRate}) {
  final parts = <Float32List>[];
  for (final s in segments) {
    final n = (s.seconds * sampleRate).round();
    final seg = Float32List(n);
    if (s.hz > 0) {
      for (var i = 0; i < n; i++) {
        seg[i] = s.amp * math.sin(2 * math.pi * s.hz * i / sampleRate);
      }
    }
    parts.add(seg);
  }
  return concat(parts);
}

Float32List concat(List<Float32List> parts) {
  final total = parts.fold<int>(0, (a, p) => a + p.length);
  final out = Float32List(total);
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

/// Adds deterministic white noise (peak [amp]) to [signal] in place.
Float32List addNoise(Float32List signal, double amp, {int seed = 7}) {
  final rnd = math.Random(seed);
  for (var i = 0; i < signal.length; i++) {
    signal[i] += amp * (rnd.nextDouble() * 2 - 1);
  }
  return signal;
}

/// Tone with frequency vibrato of +/- [cents] at [rateHz].
Float32List vibratoTone(
  double hz,
  double seconds, {
  double cents = 30,
  double rateHz = 5.5,
  double amp = 0.3,
  int sampleRate = kSampleRate,
}) {
  final n = (seconds * sampleRate).round();
  final out = Float32List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final f = hz * math.pow(2, cents / 1200 * math.sin(2 * math.pi * rateHz * t));
    phase += 2 * math.pi * f / sampleRate;
    out[i] = amp * math.sin(phase);
  }
  return out;
}

/// Slices [signal] into overlapping frames.
List<Float32List> frames(
  Float32List signal, {
  int size = kFrameSize,
  int hop = kHop,
}) {
  final out = <Float32List>[];
  for (var start = 0; start + size <= signal.length; start += hop) {
    out.add(Float32List.sublistView(signal, start, start + size));
  }
  return out;
}

/// Timestamp (ms) of frame [index].
int timestampMs(int index, {int hop = kHop, int sampleRate = kSampleRate}) =>
    (index * hop * 1000 / sampleRate).round();
