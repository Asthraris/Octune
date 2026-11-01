import 'dart:math' as math;
import 'dart:typed_data';

import 'package:octune/domain/note_math.dart';

import 'pitch_analysis.dart';
import 'pitch_detector.dart';
import 'pitch_estimate.dart';

/// YIN fundamental-frequency estimator (de Cheveigné & Kawahara 2002).
///
/// [windowSize] defaults to 2048. Low instruments need larger windows: YIN
/// must see at least ~2 periods, so for E2 (~82 Hz) at 44.1 kHz prefer 4096+.
final class YinPitchDetector implements PitchDetector {
  YinPitchDetector({
    required this.minHz,
    required this.maxHz,
    this.threshold = 0.1,
    this.windowSize = 2048,
  }) : assert(minHz > 0 && maxHz > minHz, 'invalid frequency range'),
       assert(windowSize >= 4, 'windowSize must be at least 4'),
       assert(threshold > 0 && threshold < 1, 'threshold must be in (0, 1)'),
       _half = windowSize ~/ 2,
       _cmnd = Float64List(windowSize ~/ 2),
       salienceLowestMidi = frequencyToMidi(minHz).floor(),
       _salienceHighestMidi = frequencyToMidi(maxHz).ceil(),
       _salience = Float32List(
         frequencyToMidi(maxHz).ceil() - frequencyToMidi(minHz).floor() + 1,
       );

  final double minHz;
  final double maxHz;
  final double threshold;
  final int windowSize;
  final int salienceLowestMidi;

  final int _half;
  final Float64List _cmnd;
  final int _salienceHighestMidi;
  final Float32List _salience;

  @override
  PitchAnalysis analyze(Float32List samples, int sampleRate) {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    _salience.fillRange(0, _salience.length, 0);

    final int n = math.min(samples.length, windowSize);
    final int half = math.min(_half, n ~/ 2);
    if (half < 3) {
      return _result(null);
    }

    var energy = 0.0;
    for (var i = 0; i < n; i++) {
      energy += samples[i] * samples[i];
    }
    if (energy < 1e-20) {
      return _result(null);
    }

    _difference(samples, half);
    _cumulativeMeanNormalizedDifference(half);
    _fillSalience(sampleRate, half);

    final int? tau = _absoluteThreshold(sampleRate, half);
    if (tau == null) {
      return _result(null);
    }
    final double betterTau = _parabolicTau(tau, half);
    if (betterTau <= 0) {
      return _result(null);
    }
    final double hz = sampleRate / betterTau;
    if (hz < minHz || hz > maxHz) {
      return _result(null);
    }
    final double cmnd = _cmnd[tau];
    final double clarity = (1 - cmnd).clamp(0, 1).toDouble();
    return _result(PitchEstimate(frequencyHz: hz, clarity: clarity));
  }

  PitchAnalysis _result(PitchEstimate? estimate) {
    return PitchAnalysis(
      estimate: estimate,
      salienceBySemitone: _salience,
      salienceLowestMidi: salienceLowestMidi,
    );
  }

  void _difference(Float32List x, int half) {
    _cmnd[0] = 0;
    for (var tau = 1; tau < half; tau++) {
      var sum = 0.0;
      for (var j = 0; j < half; j++) {
        final double delta = x[j] - x[j + tau];
        sum += delta * delta;
      }
      _cmnd[tau] = sum;
    }
  }

  void _cumulativeMeanNormalizedDifference(int half) {
    _cmnd[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau < half; tau++) {
      running += _cmnd[tau];
      if (running < 1e-30) {
        _cmnd[tau] = 1;
      } else {
        _cmnd[tau] *= tau / running;
      }
    }
  }

  void _fillSalience(int sampleRate, int half) {
    final int tauMin = _tauMin(sampleRate);
    final int tauMax = _tauMax(sampleRate, half);
    for (var lag = math.max(tauMin, 1); lag <= tauMax; lag++) {
      final double hz = sampleRate / lag;
      if (hz < minHz || hz > maxHz) {
        continue;
      }
      final int midi = frequencyToMidi(hz).round();
      if (midi < salienceLowestMidi || midi > _salienceHighestMidi) {
        continue;
      }
      final double value = math.max(0, 1 - _cmnd[lag]);
      final int bin = midi - salienceLowestMidi;
      if (value > _salience[bin]) {
        _salience[bin] = value;
      }
    }
  }

  int? _absoluteThreshold(int sampleRate, int half) {
    final int tauMin = _tauMin(sampleRate);
    final int tauMax = _tauMax(sampleRate, half);
    for (var tau = tauMin; tau < tauMax; tau++) {
      if (_cmnd[tau] < threshold) {
        while (tau + 1 < tauMax && _cmnd[tau + 1] < _cmnd[tau]) {
          tau++;
        }
        return tau;
      }
    }
    return null;
  }

  double _parabolicTau(int tau, int half) {
    if (tau < 1 || tau + 1 >= half) {
      return tau.toDouble();
    }
    final double s0 = _cmnd[tau - 1];
    final double s1 = _cmnd[tau];
    final double s2 = _cmnd[tau + 1];
    final double denom = 2 * ((2 * s1) - s2 - s0);
    if (denom.abs() < 1e-12) {
      return tau.toDouble();
    }
    return tau + ((s2 - s0) / denom);
  }

  int _tauMin(int sampleRate) {
    return math.max(2, (sampleRate / maxHz).floor());
  }

  int _tauMax(int sampleRate, int half) {
    return math.min(half - 1, (sampleRate / minHz).ceil());
  }
}
