import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/listening_controller.dart';
import '../application/listening_state.dart';
import '../application/metronome_controller.dart';
import '../application/selectors.dart';
import '../application/settings_controller.dart';
import '../domain/note_math.dart';
import '../domain/note_name.dart';

/// TEMPORARY screen for checking the whole loop on a device (microphone ->
/// note, level, metronome) before the real UI (Unit 5) replaces it.
/// Uses only providers from lib/application.
class DebugHome extends ConsumerWidget {
  const DebugHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(captureStatusProvider);
    final error = ref.watch(errorMessageProvider);
    final midi = ref.watch(currentMidiProvider);
    final cents = ref.watch(centsProvider);
    final hz = ref.watch(detectedHzProvider);
    final level = ref.watch(amplitudeProvider);
    final gateOpen = ref.watch(gateOpenProvider);
    final recent = ref.watch(recentNotesProvider);
    final accidentals =
        ref.watch(settingsProvider.select((s) => s.ui.accidentalPreference));
    final metronome = ref.watch(metronomeProvider);
    final hint = ref.watch(headphonesHintProvider);

    String label(int m) {
      final n = NoteReading.fromMidi(m);
      return '${n.noteName.displayName(accidentals)}${n.octave}';
    }

    final listening = status == ListeningStatus.listening;

    return Scaffold(
      appBar: AppBar(title: const Text('Octune (debug)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              midi == null ? '—' : label(midi),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w600),
            ),
            Text(
              midi == null || cents == null
                  ? ' '
                  : '${cents >= 0 ? '+' : ''}$cents¢   ${hz?.toStringAsFixed(1) ?? ''} Hz',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              recent.midiNotes.map(label).join('   '),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: ((level.db + 70) / 70).clamp(0.0, 1.0)),
            Text(
              '${level.db.toStringAsFixed(0)} dB   gate ${gateOpen ? 'open' : 'closed'}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text('status: ${status.name}', textAlign: TextAlign.center),
            if (error != null)
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.read(listeningProvider.notifier).toggle(),
              child: Text(listening ? 'Stop listening' : 'Start listening'),
            ),
            if (status == ListeningStatus.permissionPermanentlyDenied)
              TextButton(
                onPressed: () =>
                    ref.read(listeningProvider.notifier).openPermissionSettings(),
                child: const Text('Open settings'),
              ),
            const Divider(height: 32),
            Text(
              'Metronome  ${metronome.settings.bpm} BPM  '
              '${metronome.settings.beatsPerBar}/${metronome.settings.beatUnit}'
              '${metronome.lastBeat == null ? '' : '   beat ${metronome.lastBeat!.beatInBar + 1}'}',
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => ref.read(metronomeProvider.notifier).nudgeBpm(-5),
                  icon: const Icon(Icons.remove),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(metronomeProvider.notifier).tapTempo(),
                  child: const Text('Tap'),
                ),
                IconButton(
                  onPressed: () => ref.read(metronomeProvider.notifier).nudgeBpm(5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            FilledButton.tonal(
              onPressed: () => ref.read(metronomeProvider.notifier).toggle(),
              child: Text(metronome.running ? 'Stop metronome' : 'Start metronome'),
            ),
            if (metronome.errorMessage != null)
              Text(metronome.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
            if (hint)
              const Text('Use headphones so the click is not picked up by the microphone.',
                  textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
