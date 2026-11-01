import 'dart:typed_data';

/// Writes [src] minus its mean into [dst] (same length). Does not modify
/// [src], so caller-owned buffers stay intact.
void removeDcOffset(Float32List src, Float32List dst) {
  assert(dst.length >= src.length);
  if (src.isEmpty) return;
  var sum = 0.0;
  for (var i = 0; i < src.length; i++) {
    sum += src[i];
  }
  final mean = sum / src.length;
  for (var i = 0; i < src.length; i++) {
    dst[i] = src[i] - mean;
  }
}
