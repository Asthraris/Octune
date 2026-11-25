import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/app_lifecycle_source.dart';
import '../audio/audio_input.dart';
import '../audio/metronome_engine.dart';
import '../audio/permission_service.dart';
import '../audio/wakelock_service.dart';
import '../data/settings_store.dart';
import '../domain/beat_event.dart';
import '../domain/frame_analyzer.dart';

/// Infrastructure the application layer depends on, as interfaces.
///
/// The real implementations are supplied once, at the composition root
/// (`lib/app_wiring.dart`). Tests override them with fakes. Reading one that
/// was never wired fails loudly instead of doing something unexpected.
Never _notWired(String name) => throw UnimplementedError(
    '$name is not wired. Override it in lib/app_wiring.dart or in your test.');

final audioInputProvider =
    Provider<AudioInput>((ref) => _notWired('audioInputProvider'));

final permissionServiceProvider =
    Provider<PermissionService>((ref) => _notWired('permissionServiceProvider'));

/// The DSP pipeline. Create it from the stored detector settings.
final frameAnalyzerProvider =
    Provider<FrameAnalyzer>((ref) => _notWired('frameAnalyzerProvider'));

final metronomeEngineProvider =
    Provider<MetronomeEngine>((ref) => _notWired('metronomeEngineProvider'));

final settingsStoreProvider =
    Provider<SettingsStore>((ref) => _notWired('settingsStoreProvider'));

final wakelockServiceProvider =
    Provider<WakelockService>((ref) => _notWired('wakelockServiceProvider'));

final appLifecycleSourceProvider = Provider<AppLifecycleSource>(
    (ref) => _notWired('appLifecycleSourceProvider'));

/// Monotonic clock for tap tempo and beat timing. Safe default.
final clockProvider = Provider<MonotonicClock>((ref) => SystemMonotonicClock());
