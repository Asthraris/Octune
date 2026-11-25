import 'dart:typed_data';

/// Converts little-endian signed 16-bit PCM bytes to floats in -1..1.
///
/// Stream chunks can split a sample across two chunks; a stray byte is
/// carried over to the next call.
class Pcm16Decoder {
  int? _carry;

  Float32List decode(Uint8List bytes) {
    final carry = _carry;
    final total = bytes.length + (carry == null ? 0 : 1);
    final out = Float32List(total ~/ 2);
    var o = 0;
    var i = 0;
    if (carry != null) {
      if (bytes.isEmpty) return out;
      out[o++] = _sample(carry, bytes[0]);
      i = 1;
      _carry = null;
    }
    while (i + 1 < bytes.length) {
      out[o++] = _sample(bytes[i], bytes[i + 1]);
      i += 2;
    }
    if (i < bytes.length) _carry = bytes[i];
    return out;
  }

  void reset() => _carry = null;

  static double _sample(int lo, int hi) {
    var v = (hi << 8) | lo;
    if (v >= 0x8000) v -= 0x10000;
    return v / 32768.0;
  }
}
