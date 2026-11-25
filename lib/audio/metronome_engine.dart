import '../../domain/beat_event.dart';
import '../../domain/metronome_settings.dart';

/// Plays the click and announces beats.
abstract interface class MetronomeEngine {
  /// Beats, announced shortly before they sound. Broadcast.
  Stream<BeatEvent> get beats;

  bool get isRunning;

  /// Starts at beat 0. Throws if audio cannot start.
  Future<void> start(MetronomeSettings settings);

  /// Applies new settings. A changed BPM, bar length, accent or subdivision
  /// restarts the bar from beat 0; a volume change is seamless.
  Future<void> updateSettings(MetronomeSettings settings);

  Future<void> stop();

  Future<void> dispose();
}
