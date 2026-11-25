import 'dart:async';
import 'dart:typed_data';

import 'audio_input.dart';
import 'frame_chunker.dart';

/// Test double and no-microphone demo source.
///
/// Manual mode: call [feed] with samples. Demo mode: construct with
/// [FakeAudioInput.looping] to play a signal in real time while running.
class FakeAudioInput implements AudioInput {
  FakeAudioInput({this.sampleRate = 44100, this.frameSize = 2048, this.hop = 1024})
      : _loop = null {
    _chunker = FrameChunker(sampleRate: sampleRate, frameSize: frameSize, hop: hop);
  }

  FakeAudioInput.looping(
    Float32List signal, {
    this.sampleRate = 44100,
    this.frameSize = 2048,
    this.hop = 1024,
  }) : _loop = signal {
    _chunker = FrameChunker(sampleRate: sampleRate, frameSize: frameSize, hop: hop);
  }

  final int sampleRate;
  final int frameSize;
  final int hop;
  final Float32List? _loop;

  late FrameChunker _chunker;
  final _frames = StreamController<AudioFrameChunk>.broadcast();
  final _events = StreamController<AudioInputEvent>.broadcast();
  Timer? _timer;
  int _loopPos = 0;
  bool _running = false;
  bool _disposed = false;

  /// When set, [start] throws this.
  Object? failOnStart;

  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<AudioFrameChunk> get frames => _frames.stream;

  @override
  Stream<AudioInputEvent> get events => _events.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    final failure = failOnStart;
    if (failure != null) throw failure;
    if (_running) return;
    _running = true;
    startCount++;
    _chunker.reset();
    final loop = _loop;
    if (loop != null && loop.isNotEmpty) {
      _timer = Timer.periodic(
        Duration(microseconds: (hop * 1000000 / sampleRate).round()),
        (_) {
          final block = Float32List(hop);
          for (var i = 0; i < hop; i++) {
            block[i] = loop[_loopPos];
            _loopPos = (_loopPos + 1) % loop.length;
          }
          feed(block);
        },
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    stopCount++;
    _timer?.cancel();
    _timer = null;
  }

  /// Pushes samples as if they came from the microphone. Ignored when stopped.
  void feed(Float32List samples) {
    if (!_running || _disposed) return;
    for (final f in _chunker.add(samples)) {
      _frames.add(f);
    }
  }

  /// Emits an input event (interruption, error, ...).
  void emit(AudioInputEvent event) {
    if (!_disposed) _events.add(event);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _frames.close();
    await _events.close();
  }
}
