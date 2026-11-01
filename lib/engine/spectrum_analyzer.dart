import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/spectrum_view.dart';
import 'fft.dart';

/// One local maximum of the magnitude spectrum.
class SpectralPeak {
  const SpectralPeak(this.frequencyHz, this.magnitudeDb);

  /// Interpolated, so accurate to well under one FFT bin.
  final double frequencyHz;

  /// Sine-amplitude dB: a full-scale sine reads about 0 dB.
  final double magnitudeDb;
}

class SpectrumAnalysis {
  const SpectrumAnalysis({required this.view, required this.peaks});

  final SpectrumView view;

  /// Strongest first, at most [SpectrumAnalyzer.maxPeaks].
  final List<SpectralPeak> peaks;
}

/// Hann-windowed FFT -> log-spaced display bins + interpolated peaks.
///
/// FFT resolution is sampleRate / fftSize (~21.5 Hz at 2048 / 44.1 kHz), so
/// peak frequencies come from parabolic interpolation on the dB spectrum.
class SpectrumAnalyzer {
  SpectrumAnalyzer({
    this.fftSize = 2048,
    this.binCount = 64,
    this.displayMinHz = 50,
    this.displayMaxHz = 4000,
    this.maxPeaks = 8,
    this.peakRelativeFloorDb = 30,
  })  : _fft = Fft(fftSize),
        _re = Float64List(fftSize),
        _im = Float64List(fftSize),
        _window = Float64List(fftSize),
        _mag = Float64List(fftSize ~/ 2 + 1),
        _db = Float64List(fftSize ~/ 2 + 1) {
    var sum = 0.0;
    for (var i = 0; i < fftSize; i++) {
      _window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / fftSize);
      sum += _window[i];
    }
    _scale = 2 / sum; // a sine of amplitude A then reads A at its bin
  }

  final int fftSize;
  final int binCount;
  final double displayMinHz;
  final double displayMaxHz;
  final int maxPeaks;

  /// Peaks more than this many dB below the strongest are dropped.
  final double peakRelativeFloorDb;

  final Fft _fft;
  final Float64List _re;
  final Float64List _im;
  final Float64List _window;
  final Float64List _mag;
  final Float64List _db;
  late final double _scale;

  static double _toDb(double magnitude) =>
      20 * math.log(math.max(magnitude, 1e-9)) / math.ln10;

  /// [noiseFloorDb] is the gate's floor (RMS dBFS). Peaks below it are
  /// ignored and the view's peak is null. Frames longer than [fftSize] use
  /// their newest samples; shorter ones are zero-padded.
  SpectrumAnalysis analyze(
    Float32List samples,
    int sampleRate, {
    double noiseFloorDb = -90,
  }) {
    final n = fftSize;
    final off = math.max(0, samples.length - n);
    final len = math.min(samples.length, n);
    for (var i = 0; i < len; i++) {
      _re[i] = samples[off + i] * _window[i];
      _im[i] = 0;
    }
    for (var i = len; i < n; i++) {
      _re[i] = 0;
      _im[i] = 0;
    }
    _fft.transform(_re, _im);

    final half = n ~/ 2;
    for (var k = 0; k <= half; k++) {
      _mag[k] = math.sqrt(_re[k] * _re[k] + _im[k] * _im[k]) * _scale;
      _db[k] = _toDb(_mag[k]);
    }
    final binHz = sampleRate / n;

    final peaks = _findPeaks(binHz, noiseFloorDb);
    final view = SpectrumView(
      magnitudesDb: _logBins(binHz),
      minHz: displayMinHz,
      maxHz: displayMaxHz,
      peakHz: peaks.isEmpty ? null : peaks.first.frequencyHz,
      peakDb: peaks.isEmpty ? -90 : peaks.first.magnitudeDb,
    );
    return SpectrumAnalysis(view: view, peaks: peaks);
  }

  List<SpectralPeak> _findPeaks(double binHz, double noiseFloorDb) {
    final kLo = math.max(2, (displayMinHz / binHz).floor());
    final kHi = math.min(fftSize ~/ 2 - 2, (displayMaxHz / binHz).ceil());
    final found = <SpectralPeak>[];
    for (var k = kLo; k <= kHi; k++) {
      final b = _db[k];
      if (b <= noiseFloorDb || b < _db[k - 1] || b <= _db[k + 1]) continue;
      final a = _db[k - 1];
      final c = _db[k + 1];
      final denom = a - 2 * b + c;
      final delta = denom.abs() < 1e-12 ? 0.0 : 0.5 * (a - c) / denom;
      found.add(SpectralPeak(
        (k + delta) * binHz,
        b - 0.25 * (a - c) * delta,
      ));
    }
    if (found.isEmpty) return const [];
    found.sort((x, y) => y.magnitudeDb.compareTo(x.magnitudeDb));
    final strongest = found.first.magnitudeDb;
    final kept = <SpectralPeak>[];
    for (final p in found) {
      if (kept.length >= maxPeaks) break;
      if (p.magnitudeDb < strongest - peakRelativeFloorDb) break;
      if (p.magnitudeDb <= noiseFloorDb) break;
      kept.add(p);
    }
    return kept;
  }

  Float32List _logBins(double binHz) {
    final out = Float32List(binCount);
    final ratio = displayMaxHz / displayMinHz;
    final maxK = fftSize ~/ 2;
    for (var i = 0; i < binCount; i++) {
      final lo = displayMinHz * math.pow(ratio, i / binCount);
      final hi = displayMinHz * math.pow(ratio, (i + 1) / binCount);
      final center = math.sqrt(lo * hi);
      // Linear interpolation of magnitude at the centre (low bins are finer
      // than one FFT bin) ...
      final p = (center / binHz).clamp(0.0, maxK - 1.0);
      final k0 = p.floor();
      final frac = p - k0;
      var m = _mag[k0] * (1 - frac) + _mag[k0 + 1] * frac;
      // ... and the strongest FFT bin inside the range (high bins are
      // coarser than one FFT bin).
      final kA = (lo / binHz).ceil();
      final kB = math.min((hi / binHz).floor(), maxK);
      for (var k = kA; k <= kB; k++) {
        if (_mag[k] > m) m = _mag[k];
      }
      out[i] = _toDb(m);
    }
    return out;
  }
}
