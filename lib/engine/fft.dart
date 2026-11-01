import 'dart:math' as math;
import 'dart:typed_data';

/// In-place radix-2 complex FFT with precomputed twiddles. Reuse one
/// instance per size; [transform] allocates nothing.
class Fft {
  Fft(this.size) {
    if (size < 2 || (size & (size - 1)) != 0) {
      throw ArgumentError.value(size, 'size', 'must be a power of two >= 2');
    }
    _cos = Float64List(size ~/ 2);
    _sin = Float64List(size ~/ 2);
    for (var k = 0; k < size ~/ 2; k++) {
      _cos[k] = math.cos(2 * math.pi * k / size);
      _sin[k] = math.sin(2 * math.pi * k / size);
    }
    _rev = Int32List(size);
    final bits = (math.log(size) / math.ln2).round();
    for (var i = 0; i < size; i++) {
      var r = 0;
      for (var b = 0; b < bits; b++) {
        if ((i >> b) & 1 == 1) r |= 1 << (bits - 1 - b);
      }
      _rev[i] = r;
    }
  }

  final int size;
  late final Float64List _cos;
  late final Float64List _sin;
  late final Int32List _rev;

  /// Forward transform of ([re], [im]) in place.
  void transform(Float64List re, Float64List im) {
    assert(re.length == size && im.length == size);
    for (var i = 0; i < size; i++) {
      final j = _rev[i];
      if (j > i) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= size; len <<= 1) {
      final half = len >> 1;
      final step = size ~/ len;
      for (var i = 0; i < size; i += len) {
        for (var k = 0; k < half; k++) {
          final a = i + k;
          final b = a + half;
          final wr = _cos[k * step];
          final wi = -_sin[k * step];
          final tr = re[b] * wr - im[b] * wi;
          final ti = re[b] * wi + im[b] * wr;
          re[b] = re[a] - tr;
          im[b] = im[a] - ti;
          re[a] += tr;
          im[a] += ti;
        }
      }
    }
  }
}
