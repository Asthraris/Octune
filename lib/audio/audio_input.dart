import 'dart:typed_data';

/// A fixed-size frame of mono samples (-1..1) ready for analysis.
class AudioFrameChunk {
  const AudioFrameChunk({
    required this.samples,
    required this.sampleRate,
    required this.timestampMs,
  });

  final Float32List samples;
  final int sampleRate;

  /// Time of the frame's LAST sample, in ms since the input started,
  /// derived from the sample count (not the wall clock).
  final int timestampMs;
}

enum AudioInputEventType { interrupted, resumed, deviceChanged, error }

class AudioInputEvent {
  const AudioInputEvent(this.type, [this.message]);

  final AudioInputEventType type;
  final String? message;

  @override
  String toString() => 'AudioInputEvent($type${message == null ? '' : ': $message'})';
}

/// Microphone (or substitute) as a stream of analysis frames.
abstract interface class AudioInput {
  /// Frames of 2048 samples with 50% overlap. Valid while running.
  Stream<AudioFrameChunk> get frames;

  /// Interruptions (calls), device changes and errors.
  Stream<AudioInputEvent> get events;

  bool get isRunning;

  /// Starts capture. Throws if capture cannot start.
  Future<void> start();

  Future<void> stop();

  /// Releases all resources. The input cannot be used afterwards.
  Future<void> dispose();
}
