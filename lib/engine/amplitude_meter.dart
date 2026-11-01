import 'dart:math' as math;
import 'dart:typed_data';

class AmplitudeReading {
  const AmplitudeReading({required this.linear, required this.db});

  /// RMS level, 0..1 (a full-scale sine reads ~0.707).
  final double linear;

  /// RMS level in dBFS, floored at [AmplitudeMeter.floorDb].
  final double db;
}

/// RMS level meter.
class AmplitudeMeter {
  static const double floorDb = -90;

  AmplitudeReading measure(Float32List samples) {
    if (samples.isEmpty) return const AmplitudeReading(linear: 0, db: floorDb);
    var sum = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples.length);
    final linear = rms.clamp(0.0, 1.0).toDouble();
    final db = linear <= 0 ? floorDb : 20 * math.log(linear) / math.ln10;
    return AmplitudeReading(linear: linear, db: math.max(db, floorDb));
  }
}
