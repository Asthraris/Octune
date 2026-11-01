import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/note_math.dart';
import 'pitch_detector.dart';

/// YIN pitch detector (de Cheveigné & Kawahara, 2002).
///
/// Steps: difference function -> cumulative mean normalized difference
/// (CMND) -> absolute threshold -> parabolic interpolation.
///
/// Window trade-off: the search needs `windowSize / 2` samples of lag, so the
/// lowest detectable pitch is `sampleRate / (windowSize / 2)`:
/// 2048 @ 44.1 kHz -> ~43 Hz. Lower instruments (bass E1 = 41 Hz) need a
/// 4096 window, at the cost of ~46 ms extra latency. Ranges asking for
/// lower notes are clamped automatically (see [effectiveMinHz]).
///
/// Cost per frame is roughly `tauMax * (windowSize - tauMax)` multiply-adds.
class YinPitchDetector implements PitchDetector {
  YinPitchDetector({
    double minHz = 65,
    double maxHz = 2100,
    this.threshold = 0.2,
    this.windowSize = 2048,
    this.subharmonicPenalty = 0.4,
  })  : _minHz = minHz,
        _maxHz = maxHz;

  /// CMND level below which a lag counts as the period (lower = stricter).
  final double threshold;
  final int windowSize;

  /// Salience of low lags is favoured over their multiples (sub-octaves) by
  /// scaling the strength of long lags down by up to this fraction. Only
  /// affects [PitchAnalysis.salienceBySemitone], not the pitch estimate.
  final double subharmonicPenalty;

  double _minHz;
  double _maxHz;

  int? _preparedRate;
  int _tauMin = 2;
  int _tauMax = 3;
  int _integrationLength = 0;
  int _lowestMidi = 0;
  int _binCount = 0;
  Float64List _cmnd = Float64List(0);
  Int32List _tauToBin = Int32List(0);
  Float64List _tauWeight = Float64List(0);
  List<bool> _binHasLag = const [];
  Float64List _binCenterTau = Float64List(0);

  /// Lowest frequency actually searched (after window clamping).
  /// Valid after the first analyze/emptyAnalysis call.
  double get effectiveMinHz =>
      _preparedRate == null ? _minHz : _preparedRate! / _tauMax;

  @override
  void setFrequencyRange(double minHz, double maxHz) {
    if (minHz == _minHz && maxHz == _maxHz) return;
    _minHz = minHz;
    _maxHz = maxHz;
    _preparedRate = null; // re-prepare lazily
  }

  void _prepare(int sampleRate) {
    if (_preparedRate == sampleRate) return;

    final tauMax = math.min((sampleRate / _minHz).ceil(), windowSize ~/ 2);
    var tauMin = math.max(2, (sampleRate / _maxHz).floor());
    if (tauMin > tauMax - 3) tauMin = math.max(2, tauMax - 3);
    _tauMin = tauMin;
    _tauMax = tauMax;
    _integrationLength = windowSize - tauMax;

    _lowestMidi = frequencyToMidi(sampleRate / tauMax).round();
    final highestMidi = frequencyToMidi(sampleRate / tauMin).round();
    _binCount = highestMidi - _lowestMidi + 1;

    _cmnd = Float64List(tauMax + 1);
    _tauToBin = Int32List(tauMax + 1);
    _tauWeight = Float64List(tauMax + 1);
    _binHasLag = List<bool>.filled(_binCount, false);
    _binCenterTau = Float64List(_binCount);

    final logSpan = math.log(tauMax / tauMin);
    for (var tau = tauMin; tau <= tauMax; tau++) {
      final midi = frequencyToMidi(sampleRate / tau);
      final bin = (midi.round() - _lowestMidi).clamp(0, _binCount - 1);
      _tauToBin[tau] = bin;
      _binHasLag[bin] = true;
      _tauWeight[tau] = 1 - subharmonicPenalty * math.log(tau / tauMin) / logSpan;
    }
    for (var b = 0; b < _binCount; b++) {
      _binCenterTau[b] =
          sampleRate / midiToFrequency((_lowestMidi + b).toDouble());
    }
    _preparedRate = sampleRate;
  }

  @override
  PitchAnalysis emptyAnalysis(int sampleRate) {
    _prepare(sampleRate);
    return PitchAnalysis(
      estimate: null,
      salienceBySemitone: Float32List(_binCount),
      salienceLowestMidi: _lowestMidi,
    );
  }

  @override
  PitchAnalysis analyze(Float32List samples, int sampleRate) {
    _prepare(sampleRate);
    if (samples.length < windowSize) return emptyAnalysis(sampleRate);

    final off = samples.length - windowSize; // newest samples
    final n = _integrationLength;
    final cmnd = _cmnd;

    // Difference function + cumulative mean normalisation, one pass.
    cmnd[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= _tauMax; tau++) {
      var sum = 0.0;
      final a = off;
      final b = off + tau;
      for (var j = 0; j < n; j++) {
        final delta = samples[a + j] - samples[b + j];
        sum += delta * delta;
      }
      running += sum;
      cmnd[tau] = running > 1e-12 ? sum * tau / running : 1.0;
    }

    // Absolute threshold: first lag under threshold, then walk to its minimum.
    int? best;
    for (var tau = _tauMin; tau < _tauMax; tau++) {
      if (cmnd[tau] < threshold) {
        while (tau + 1 < _tauMax && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }

    PitchEstimate? estimate;
    if (best != null) {
      var refined = best.toDouble();
      if (best > 1 && best < _tauMax) {
        final a = cmnd[best - 1];
        final b = cmnd[best];
        final c = cmnd[best + 1];
        final denom = a - 2 * b + c;
        if (denom.abs() > 1e-12) {
          final shift = 0.5 * (a - c) / denom;
          if (shift.abs() < 1) refined += shift;
        }
      }
      estimate = PitchEstimate(
        frequencyHz: sampleRate / refined,
        clarity: (1 - cmnd[best]).clamp(0.0, 1.0).toDouble(),
      );
    }

    // Per-semitone salience from the same CMND (no extra FFT).
    final salience = Float32List(_binCount);
    for (var tau = _tauMin; tau <= _tauMax; tau++) {
      final v = (1 - cmnd[tau]) * _tauWeight[tau];
      final bin = _tauToBin[tau];
      if (v > salience[bin]) salience[bin] = v;
    }
    // High semitones can fall between integer lags: interpolate those bins.
    for (var bin = 0; bin < _binCount; bin++) {
      if (_binHasLag[bin]) continue;
      final tau = _binCenterTau[bin];
      final lo = tau.floor().clamp(_tauMin, _tauMax - 1);
      final frac = (tau - lo).clamp(0.0, 1.0);
      final v = (1 - (cmnd[lo] * (1 - frac) + cmnd[lo + 1] * frac)) *
          _tauWeight[lo];
      salience[bin] = v > 0 ? v : 0;
    }

    return PitchAnalysis(
      estimate: estimate,
      salienceBySemitone: salience,
      salienceLowestMidi: _lowestMidi,
    );
  }
}
