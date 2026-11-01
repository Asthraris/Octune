import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/amplitude_meter.dart';
import 'package:octune/engine/dc_removal.dart';

import '../helpers/signals.dart';

void main() {
  final meter = AmplitudeMeter();

  group('AmplitudeMeter', () {
    test('silence reads the floor', () {
      final r = meter.measure(silence());
      expect(r.linear, 0);
      expect(r.db, AmplitudeMeter.floorDb);
    });
    test('sine of amplitude 0.5 is about -9 dBFS', () {
      final r = meter.measure(sine(440, amp: 0.5));
      expect(r.linear, closeTo(0.3536, 0.002));
      expect(r.db, closeTo(-9.03, 0.1));
    });
    test('full-scale constant is 0 dBFS', () {
      final r = meter.measure(Float32List(100)..fillRange(0, 100, 1.0));
      expect(r.linear, closeTo(1, 1e-6));
      expect(r.db, closeTo(0, 1e-6));
    });
    test('louder reads higher', () {
      expect(meter.measure(sine(440, amp: 0.8)).db,
          greaterThan(meter.measure(sine(440, amp: 0.1)).db));
    });
    test('empty input is safe', () {
      expect(meter.measure(Float32List(0)).db, AmplitudeMeter.floorDb);
    });
  });

  group('removeDcOffset', () {
    test('removes a constant offset and leaves the source untouched', () {
      final src = sine(440, amp: 0.2);
      for (var i = 0; i < src.length; i++) {
        src[i] += 0.3;
      }
      final dst = Float32List(src.length);
      removeDcOffset(src, dst);
      var sum = 0.0;
      for (final v in dst) {
        sum += v;
      }
      expect((sum / dst.length).abs(), lessThan(1e-4));
      expect(src[0], closeTo(0.3, 0.2)); // source unchanged (still offset)
      expect(meter.measure(dst).linear, closeTo(0.2 / 1.4142, 0.005));
    });
  });
}
