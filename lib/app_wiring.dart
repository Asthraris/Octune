import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/providers.dart';
import 'application/settings_controller.dart';
import 'audio/demo_signal.dart';
import 'audio/fake_audio_input.dart';
import 'audio/fakes.dart';
import 'audio/platform/flutter_app_lifecycle_source.dart';
import 'audio/platform/permission_services.dart';
import 'audio/platform/record_audio_input.dart';
import 'audio/platform/soloud_metronome_engine.dart';
import 'audio/platform/wakelock_plus_service.dart';
import 'data/shared_preferences_settings_store.dart';
import 'engine/pitch_pipeline.dart';

/// The composition root: the only place that knows the real plugins.
/// Everything else depends on interfaces, and tests override the same
/// providers with fakes.
///
/// [useDemoInput] replaces the microphone with a looping demo melody, for
/// machines without one: `flutter run --dart-define=OCTUNE_DEMO=true`.
Future<List<Override>> buildProductionOverrides({bool useDemoInput = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final recorder = AudioRecorder();

  return [
    settingsStoreProvider.overrideWithValue(SharedPreferencesSettingsStore(prefs)),
    permissionServiceProvider.overrideWithValue(
      useDemoInput ? FakePermissionService() : createPlatformPermissionService(recorder),
    ),
    audioInputProvider.overrideWith((ref) {
      final input = useDemoInput
          ? FakeAudioInput.looping(demoMelody())
          : RecordAudioInput(recorder: recorder);
      ref.onDispose(input.dispose);
      return input;
    }),
    // Created from the stored settings; the ListeningController keeps it
    // in step with later changes.
    frameAnalyzerProvider.overrideWith(
      (ref) => PitchPipeline.standard(settings: ref.read(settingsProvider).detector),
    ),
    // Shares the app clock, so beat times and the UI use one timeline.
    metronomeEngineProvider.overrideWith((ref) {
      final engine = SoloudMetronomeEngine(clock: ref.read(clockProvider));
      ref.onDispose(engine.dispose);
      return engine;
    }),
    wakelockServiceProvider.overrideWithValue(WakelockPlusService()),
    appLifecycleSourceProvider.overrideWith((ref) {
      final source = FlutterAppLifecycleSource();
      ref.onDispose(source.dispose);
      return source;
    }),
  ];
}
