import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/audio/audio_input.dart';
import 'package:octune/audio/demo_signal.dart';
import 'package:octune/audio/fake_audio_input.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/engine/pitch_pipeline.dart';

import '../helpers/signals.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('feed is ignored until started and after stopped', () async {
    final input = FakeAudioInput();
    final frames = <AudioFrameChunk>[];
    input.frames.listen(frames.add);
    input.feed(Float32List(4096));
    await settle();
    expect(frames, isEmpty);
    await input.start();
    input.feed(Float32List(4096));
    await settle();
    expect(frames.length, 3);
    await input.stop();
    input.feed(Float32List(4096));
    await settle();
    expect(frames.length, 3);
    expect(input.startCount, 1);
    expect(input.stopCount, 1);
  });

  test('failOnStart makes start throw', () async {
    final input = FakeAudioInput()..failOnStart = StateError('no mic');
    Object? caught;
    try {
      await input.start();
    } catch (e) {
      caught = e;
    }
    expect(caught is StateError, isTrue);
    expect(input.isRunning, isFalse);
  });

  test('events can be emitted', () async {
    final input = FakeAudioInput();
    final events = <AudioInputEvent>[];
    input.events.listen(events.add);
    input.emit(const AudioInputEvent(AudioInputEventType.interrupted));
    await settle();
    expect(events.single.type, AudioInputEventType.interrupted);
  });

  test('looping demo mode delivers frames in real time', () async {
    final input = FakeAudioInput.looping(demoMelody());
    final frames = <AudioFrameChunk>[];
    input.frames.listen(frames.add);
    await input.start();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await input.stop();
    await input.dispose();
    expect(frames.length, greaterThanOrEqualTo(3));
  });

  test('end to end: demo melody through FakeAudioInput and the pipeline', () async {
    final input = FakeAudioInput();
    final pipeline = PitchPipeline.standard();
    final labels = <String?>[];
    input.frames.listen((f) {
      final s = pipeline.process(f.samples, f.sampleRate, f.timestampMs);
      final e = s.stableNote;
      final l = e == null ? null : '${e.noteName.asciiName}${e.octave}';
      if (labels.isEmpty || labels.last != l) labels.add(l);
    });
    await input.start();
    final signal = demoMelody();
    for (var i = 0; i + 1024 <= signal.length; i += 1024) {
      input.feed(Float32List.sublistView(signal, i, i + 1024));
    }
    await settle();
    expect(labels.whereType<String>().toList(),
        equals(['A3', 'C4', 'E4', 'G4', 'A4', 'C5']));
    expect(kHop, 1024);
  });
}
