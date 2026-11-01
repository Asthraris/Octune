import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/engine/fft.dart';

void main() {
  test('rejects sizes that are not powers of two', () {
    expect(() => Fft(100), throwsArgumentError);
    expect(() => Fft(1), throwsArgumentError);
  });

  test('impulse gives a flat spectrum', () {
    final fft = Fft(64);
    final re = Float64List(64)..[0] = 1;
    final im = Float64List(64);
    fft.transform(re, im);
    for (var k = 0; k < 64; k++) {
      expect(re[k], closeTo(1, 1e-9));
      expect(im[k], closeTo(0, 1e-9));
    }
  });

  test('cosine at bin 8 lands in bin 8 with magnitude N/2', () {
    const n = 64;
    final fft = Fft(n);
    final re = Float64List(n);
    final im = Float64List(n);
    for (var i = 0; i < n; i++) {
      re[i] = math.cos(2 * math.pi * 8 * i / n);
    }
    fft.transform(re, im);
    expect(math.sqrt(re[8] * re[8] + im[8] * im[8]), closeTo(n / 2, 1e-9));
    expect(math.sqrt(re[9] * re[9] + im[9] * im[9]), closeTo(0, 1e-9));
    expect(math.sqrt(re[3] * re[3] + im[3] * im[3]), closeTo(0, 1e-9));
  });

  test('matches a naive DFT', () {
    const n = 32;
    final rnd = math.Random(3);
    final x = List<double>.generate(n, (_) => rnd.nextDouble() - 0.5);
    final re = Float64List.fromList(x);
    final im = Float64List(n);
    Fft(n).transform(re, im);
    for (var k = 0; k < n; k++) {
      var sr = 0.0;
      var si = 0.0;
      for (var t = 0; t < n; t++) {
        sr += x[t] * math.cos(2 * math.pi * k * t / n);
        si -= x[t] * math.sin(2 * math.pi * k * t / n);
      }
      expect(re[k], closeTo(sr, 1e-9));
      expect(im[k], closeTo(si, 1e-9));
    }
  });
}
