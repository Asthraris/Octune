import 'dart:typed_data';

import 'audio_input.dart';

/// Re-chunks arbitrary-size sample blocks into fixed [frameSize] frames that
/// advance by [hop] samples (frameSize 2048, hop 1024 = 50% overlap).
///
/// Each returned frame is a fresh copy, safe to keep. Timestamps count
/// samples, so they are exact and independent of scheduling jitter.
class FrameChunker {
  FrameChunker({
    required this.sampleRate,
    this.frameSize = 2048,
    this.hop = 1024,
  }) : assert(hop > 0 && hop <= frameSize) {
    _buffer = Float32List(frameSize * 4);
  }

  final int sampleRate;
  final int frameSize;
  final int hop;

  late Float32List _buffer;
  int _length = 0; // buffered samples
  int _discarded = 0; // samples dropped from the front so far

  /// Adds [samples] and returns every complete frame now available.
  List<AudioFrameChunk> add(Float32List samples) {
    final needed = _length + samples.length;
    if (needed > _buffer.length) {
      final grown = Float32List(needed > _buffer.length * 2 ? needed : _buffer.length * 2);
      grown.setRange(0, _length, _buffer);
      _buffer = grown;
    }
    _buffer.setRange(_length, needed, samples);
    _length = needed;

    final out = <AudioFrameChunk>[];
    var start = 0;
    while (_length - start >= frameSize) {
      final endSample = _discarded + start + frameSize;
      out.add(AudioFrameChunk(
        samples: Float32List.fromList(
            Float32List.sublistView(_buffer, start, start + frameSize)),
        sampleRate: sampleRate,
        timestampMs: (endSample * 1000 / sampleRate).round(),
      ));
      start += hop;
    }
    if (start > 0) {
      _buffer.setRange(0, _length - start, _buffer, start);
      _length -= start;
      _discarded += start;
    }
    return out;
  }

  /// Number of samples waiting for the next frame.
  int get pending => _length;

  void reset() {
    _length = 0;
    _discarded = 0;
  }
}
