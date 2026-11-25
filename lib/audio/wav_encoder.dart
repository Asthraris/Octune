import 'dart:typed_data';

/// Encodes mono float samples as a 16-bit PCM WAV file in memory.
class WavEncoder {
  static Uint8List pcm16Mono(Float32List samples, int sampleRate) {
    final dataBytes = samples.length * 2;
    final out = Uint8List(44 + dataBytes);
    final b = ByteData.sublistView(out);
    void tag(int offset, String s) {
      for (var i = 0; i < 4; i++) {
        out[offset + i] = s.codeUnitAt(i);
      }
    }

    tag(0, 'RIFF');
    b.setUint32(4, 36 + dataBytes, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // fmt chunk size
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    b.setUint16(32, 2, Endian.little); // block align
    b.setUint16(34, 16, Endian.little); // bits per sample
    tag(36, 'data');
    b.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).round().clamp(-32768, 32767);
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return out;
  }
}
