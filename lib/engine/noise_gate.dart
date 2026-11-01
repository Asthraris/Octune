import 'dart:math' as math;

/// Adaptive noise gate.
///
/// * The noise floor starts as the mean level of the first [warmupMs], then
///   follows the signal: it falls quickly, and rises slowly while closed or
///   while the signal is not pitched. While open on a pitched signal it
///   rises extremely slowly, so a held note is not mistaken for noise.
/// * Threshold = floor + margin. Margin (dB) = 4 + 20 * noiseGate, so the
///   0..1 setting spans 4..24 dB.
/// * The floor is capped at [maxFloorDb] and the threshold never drops below
///   [absoluteMinThresholdDb], so loud-but-unpitched rooms cannot lock the
///   gate shut and digital silence cannot open it.
/// * Hysteresis ([hysteresisDb]) and a hold time ([holdMs]) stop chatter.
class NoiseGate {
  NoiseGate({
    double noiseGate = 0.33,
    this.warmupMs = 300,
    this.holdMs = 150,
    this.hysteresisDb = 3,
    this.absoluteMinThresholdDb = -65,
    this.maxFloorDb = -45,
    this.fallTauMs = 200,
    this.riseTauMs = 3000,
    this.openRiseTauMs = 60000,
  }) : _noiseGate = noiseGate.clamp(0.0, 1.0).toDouble();

  static const double minMarginDb = 4;
  static const double marginSpanDb = 20;

  final double warmupMs;
  final double holdMs;
  final double hysteresisDb;
  final double absoluteMinThresholdDb;
  final double maxFloorDb;
  final double fallTauMs;
  final double riseTauMs;
  final double openRiseTauMs;

  double _noiseGate;
  double _floorDb = -90;
  double _warmupElapsedMs = 0;
  int _warmupCount = 0;
  bool _open = false;
  double _sinceAboveMs = 0;

  bool get isOpen => _open;
  double get noiseFloorDb => _floorDb;
  double get noiseGate => _noiseGate;
  double get marginDb => minMarginDb + marginSpanDb * _noiseGate;

  /// Level a frame must exceed to open the gate.
  double get thresholdDb =>
      math.max(_floorDb + marginDb, absoluteMinThresholdDb);

  void configure({required double noiseGate}) {
    _noiseGate = noiseGate.clamp(0.0, 1.0).toDouble();
  }

  /// Sets the threshold line directly (UI drag). Adjusts the margin and
  /// returns the equivalent 0..1 noiseGate setting.
  double setThresholdDb(double db) {
    final margin = (db - _floorDb).clamp(minMarginDb, minMarginDb + marginSpanDb);
    _noiseGate = ((margin - minMarginDb) / marginSpanDb).clamp(0.0, 1.0).toDouble();
    return _noiseGate;
  }

  void reset() {
    _floorDb = -90;
    _warmupElapsedMs = 0;
    _warmupCount = 0;
    _open = false;
    _sinceAboveMs = 0;
  }

  /// Feeds one frame's level. [dtMs] is the time since the previous frame.
  /// [pitched] says whether the previous frame contained a pitch; unpitched
  /// open frames count as noise for floor adaptation.
  bool process(double levelDb, double dtMs, {bool pitched = true}) {
    final inWarmup = _warmupElapsedMs < warmupMs;
    if (inWarmup) {
      _warmupCount++;
      _warmupElapsedMs += dtMs;
      _floorDb = _warmupCount == 1
          ? levelDb
          : _floorDb + (levelDb - _floorDb) / _warmupCount;
      _floorDb = math.min(_floorDb, maxFloorDb);
    }

    // Open / close decision against the current threshold.
    final threshold = thresholdDb;
    if (levelDb > threshold) {
      _open = true;
      _sinceAboveMs = 0;
    } else if (_open) {
      _sinceAboveMs += dtMs;
      if (levelDb < threshold - hysteresisDb && _sinceAboveMs >= holdMs) {
        _open = false;
      }
    }

    if (!inWarmup) {
      final rising = levelDb >= _floorDb;
      final tau = !rising
          ? fallTauMs
          : (_open && pitched ? openRiseTauMs : riseTauMs);
      _floorDb += (levelDb - _floorDb) * (1 - math.exp(-dtMs / tau));
      _floorDb = math.min(_floorDb, maxFloorDb);
    }
    return _open;
  }
}
