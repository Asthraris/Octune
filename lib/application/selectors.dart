import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_event.dart';
import '../domain/recent_notes.dart';
import '../domain/spectrum_view.dart';
import 'listening_controller.dart';
import 'listening_state.dart';
import 'metronome_controller.dart';

/// Fine-grained views of the listening state. Each provider rebuilds its
/// watchers only when ITS value changes, so the big note letter does not
/// repaint 30 times a second when only the level meter moves.

final captureStatusProvider = Provider<ListeningStatus>(
    (ref) => ref.watch(listeningProvider.select((s) => s.status)));

final errorMessageProvider = Provider<String?>(
    (ref) => ref.watch(listeningProvider.select((s) => s.errorMessage)));

/// MIDI number of the stable note, or null. Changes only when the note does.
final currentMidiProvider = Provider<int?>((ref) =>
    ref.watch(listeningProvider.select((s) => s.snapshot.stableNote?.midiNumber)));

/// The stable note with live cents/amplitude. Changes every frame.
final stableNoteProvider = Provider<NoteEvent?>(
    (ref) => ref.watch(listeningProvider.select((s) => s.snapshot.stableNote)));

/// Whole cents of the stable note, for the cents readout.
final centsProvider = Provider<int?>((ref) => ref.watch(
    listeningProvider.select((s) => s.snapshot.stableNote?.cents.round())));

final detectedHzProvider = Provider<double?>(
    (ref) => ref.watch(listeningProvider.select((s) => s.snapshot.detectedHz)));

final confidenceProvider = Provider<double>(
    (ref) => ref.watch(listeningProvider.select((s) => s.snapshot.confidence)));

final recentNotesProvider = Provider<RecentNotes>(
    (ref) => ref.watch(listeningProvider.select((s) => s.recent)));

final amplitudeProvider = Provider<({double db, double linear})>((ref) =>
    ref.watch(listeningProvider.select((s) => (
          db: s.snapshot.amplitudeDb,
          linear: s.snapshot.amplitudeLinear,
        ))));

final gateOpenProvider = Provider<bool>(
    (ref) => ref.watch(listeningProvider.select((s) => s.snapshot.gateOpen)));

/// The dotted threshold and noise-floor lines.
final gateLinesProvider = Provider<({double thresholdDb, double noiseFloorDb})>(
    (ref) => ref.watch(listeningProvider.select((s) => (
          thresholdDb: s.snapshot.gateThresholdDb,
          noiseFloorDb: s.snapshot.noiseFloorDb,
        ))));

final spectrumProvider = Provider<SpectrumView>(
    (ref) => ref.watch(listeningProvider.select((s) => s.snapshot.spectrum)));

/// Per-semitone strength for the note-scale strip.
final salienceProvider = Provider<({Float32List data, int lowestMidi})>(
    (ref) => ref.watch(listeningProvider.select((s) => (
          data: s.snapshot.salienceBySemitone,
          lowestMidi: s.snapshot.salienceLowestMidi,
        ))));

/// 12 values (C first) for the note ring.
final pitchClassProvider = Provider<Float32List>((ref) =>
    ref.watch(listeningProvider.select((s) => s.snapshot.pitchClassEnergy)));

// -- metronome ---------------------------------------------------------------

final metronomeRunningProvider = Provider<bool>(
    (ref) => ref.watch(metronomeProvider.select((s) => s.running)));

/// True while both the microphone and the click are active: the click can
/// leak into the microphone, so suggest headphones.
final headphonesHintProvider = Provider<bool>((ref) =>
    ref.watch(captureStatusProvider) == ListeningStatus.listening &&
    ref.watch(metronomeRunningProvider));
