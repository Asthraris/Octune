import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../audio_input.dart';
import '../frame_chunker.dart';
import '../pcm16_decoder.dart';

/// Microphone capture with the `record` package (PCM16 stream).
///
/// * Asks for mono 44.1 kHz with automatic gain, echo cancellation and noise
///   suppression OFF: they distort pitch and amplitude.
/// * The platform may adjust the config (other sample rate or stereo). The
///   `setOnConfigChanged` callback keeps the chunker and downmix in step, so
///   timestamps and pitch stay correct.
/// * Interruptions (calls, other apps) are reported through [events].
class RecordAudioInput implements AudioInput {
  RecordAudioInput({
    AudioRecorder? recorder,
    this.requestedSampleRate = 44100,
    this.frameSize = 2048,
    this.hop = 1024,
  })  : _recorder = recorder ?? AudioRecorder(),
        _sampleRate = requestedSampleRate {
    _chunker = FrameChunker(sampleRate: _sampleRate, frameSize: frameSize, hop: hop);
  }

  final AudioRecorder _recorder;
  final int requestedSampleRate;
  final int frameSize;
  final int hop;

  final _frames = StreamController<AudioFrameChunk>.broadcast();
  final _events = StreamController<AudioInputEvent>.broadcast();
  final Pcm16Decoder _decoder = Pcm16Decoder();
  late FrameChunker _chunker;
  StreamSubscription<Uint8List>? _dataSub;
  StreamSubscription<RecordState>? _stateSub;

  int _sampleRate;
  int _channels = 1;
  bool _running = false;
  bool _stopping = false;
  bool _interrupted = false;
  bool _disposed = false;

  @override
  Stream<AudioFrameChunk> get frames => _frames.stream;

  @override
  Stream<AudioInputEvent> get events => _events.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    if (_running || _disposed) return;
    _stopping = false;
    _interrupted = false;
    _sampleRate = requestedSampleRate;
    _channels = 1;
    _decoder.reset();
    _chunker = FrameChunker(sampleRate: _sampleRate, frameSize: frameSize, hop: hop);

    await _recorder.setOnConfigChanged((config) {
      _channels = config.numChannels < 1 ? 1 : config.numChannels;
      if (config.sampleRate != _sampleRate) {
        _sampleRate = config.sampleRate;
        _chunker =
            FrameChunker(sampleRate: _sampleRate, frameSize: frameSize, hop: hop);
      }
    });

    final stream = await _recorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: requestedSampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      audioInterruption: AudioInterruptionMode.pauseResume,
    ));
    _running = true;
    _dataSub = stream.listen(_onBytes, onError: _onError, onDone: _onDone);
    _stateSub = _recorder.onStateChanged().listen(_onState, onError: _onError);
  }

  void _onBytes(Uint8List bytes) {
    if (!_running || _interrupted) return;
    var samples = _decoder.decode(bytes);
    if (_channels > 1) samples = _downmix(samples, _channels);
    for (final frame in _chunker.add(samples)) {
      if (!_frames.isClosed) _frames.add(frame);
    }
  }

  static Float32List _downmix(Float32List interleaved, int channels) {
    final n = interleaved.length ~/ channels;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += interleaved[i * channels + c];
      }
      out[i] = sum / channels;
    }
    return out;
  }

  void _onState(RecordState state) {
    switch (state) {
      case RecordState.pause:
        if (!_stopping && _running && !_interrupted) {
          _interrupted = true;
          _emit(const AudioInputEvent(AudioInputEventType.interrupted));
        }
      case RecordState.record:
        if (_interrupted) {
          _interrupted = false;
          _decoder.reset();
          _chunker.reset();
          _emit(const AudioInputEvent(AudioInputEventType.resumed));
        }
      case RecordState.stop:
        if (!_stopping && _running) {
          _running = false;
          _emit(const AudioInputEvent(
              AudioInputEventType.error, 'Recording stopped unexpectedly.'));
        }
    }
  }

  void _onError(Object error, StackTrace stack) {
    if (_stopping) return;
    _emit(AudioInputEvent(AudioInputEventType.error, error.toString()));
  }

  void _onDone() {
    if (!_stopping && _running) {
      _running = false;
      _emit(const AudioInputEvent(
          AudioInputEventType.error, 'The audio stream ended unexpectedly.'));
    }
  }

  void _emit(AudioInputEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Future<void> stop() async {
    if (!_running && _dataSub == null) return;
    _stopping = true;
    _running = false;
    await _dataSub?.cancel();
    await _stateSub?.cancel();
    _dataSub = null;
    _stateSub = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Already stopped by the platform; nothing to release.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    try {
      await _recorder.dispose();
    } catch (_) {}
    await _frames.close();
    await _events.close();
  }
}
