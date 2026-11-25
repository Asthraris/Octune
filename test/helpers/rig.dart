import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:octune/application/providers.dart';
import 'package:octune/audio/fake_audio_input.dart';
import 'package:octune/audio/fake_metronome_engine.dart';
import 'package:octune/audio/fakes.dart';
import 'package:octune/audio/permission_service.dart';
import 'package:octune/data/settings_codec.dart';
import 'package:octune/data/settings_store.dart';
import 'package:octune/engine/pitch_pipeline.dart';

import 'signals.dart';

/// Lets queued stream events and microtasks run.
Future<void> settle([int times = 2]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// All the fakes wired into a ProviderContainer, with the REAL DSP pipeline.
class Rig {
  Rig({
    MicPermissionStatus? permission,
    MicPermissionStatus? afterRequest,
    Map<String, String>? storeData,
  })  : store = InMemorySettingsStore(storeData),
        input = FakeAudioInput(),
        permissionService = FakePermissionService(
          current: permission ?? MicPermissionStatus.granted,
          afterRequest: afterRequest,
        ),
        metronome = FakeMetronomeEngine(),
        wakelock = FakeWakelockService(),
        lifecycle = FakeAppLifecycleSource(),
        clock = FakeClock() {
    analyzer = PitchPipeline.standard(
        settings: decodeDetector(store.read(kDetectorSettingsKey)));
    container = ProviderContainer(overrides: [
      audioInputProvider.overrideWithValue(input),
      permissionServiceProvider.overrideWithValue(permissionService),
      frameAnalyzerProvider.overrideWithValue(analyzer),
      metronomeEngineProvider.overrideWithValue(metronome),
      settingsStoreProvider.overrideWithValue(store),
      wakelockServiceProvider.overrideWithValue(wakelock),
      appLifecycleSourceProvider.overrideWithValue(lifecycle),
      clockProvider.overrideWithValue(clock),
    ]);
  }

  final InMemorySettingsStore store;
  final FakeAudioInput input;
  final FakePermissionService permissionService;
  final FakeMetronomeEngine metronome;
  final FakeWakelockService wakelock;
  final FakeAppLifecycleSource lifecycle;
  final FakeClock clock;
  late final PitchPipeline analyzer;
  late final ProviderContainer container;

  /// Feeds [signal] to the fake microphone in 1024-sample blocks.
  Future<void> play(Float32List signal) async {
    for (var i = 0; i + 1024 <= signal.length; i += 1024) {
      input.feed(Float32List.sublistView(signal, i, i + 1024));
    }
    await settle();
  }

  /// A tone preceded by silence so the gate can calibrate.
  Float32List tone(double hz, {double seconds = 1.0, double lead = 0.5}) =>
      render([Segment(0, lead), Segment(hz, seconds)]);

  void dispose() => container.dispose();
}
