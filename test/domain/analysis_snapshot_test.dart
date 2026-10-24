import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/analysis_snapshot.dart';
import 'package:octune/domain/note_event.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/spectrum_view.dart';

void main() {
  test('empty is a stable blank frame', () {
    final AnalysisSnapshot empty = AnalysisSnapshot.empty();
    expect(empty.timestampMs, 0);
    expect(empty.stableNote, isNull);
    expect(empty.detectedHz, isNull);
    expect(empty.confidence, 0);
    expect(empty.amplitudeLinear, 0);
    expect(empty.amplitudeDb, 0);
    expect(empty.gateOpen, isFalse);
    expect(empty.salienceBySemitone, isEmpty);
    expect(empty.pitchClassEnergy.length, 12);
    expect(empty.pitchClassEnergy.every((double v) => v == 0), isTrue);
    expect(empty.spectrum, SpectrumView.empty());
    expect(AnalysisSnapshot.empty(), empty);
  });

  test('copies buffers and compares by value', () {
    const NoteEvent stable = NoteEvent(
      tMs: 100,
      noteName: NoteName.a,
      octave: 4,
      cents: 0,
      amp: 0.5,
      conf: 0.9,
    );
    final Float32List salience = Float32List.fromList(<double>[0.1, 0.8]);
    final Float32List ring = Float32List(12);
    ring[9] = 1;
    final AnalysisSnapshot snapshot = AnalysisSnapshot(
      timestampMs: 100,
      stableNote: stable,
      detectedHz: 440,
      confidence: 0.9,
      amplitudeLinear: 0.5,
      amplitudeDb: -6,
      gateOpen: true,
      gateThresholdDb: -40,
      noiseFloorDb: -60,
      salienceBySemitone: salience,
      salienceLowestMidi: 48,
      pitchClassEnergy: ring,
      spectrum: SpectrumView(
        magnitudesDb: Float32List.fromList(<double>[-20]),
        minHz: 65,
        maxHz: 2100,
        peakHz: 440,
        peakDb: -3,
      ),
    );
    salience[0] = 0;
    ring[9] = 0;
    expect(snapshot.salienceBySemitone[1], closeTo(0.8, 1e-6));
    expect(snapshot.pitchClassEnergy[9], 1);
    expect(snapshot.stableNote, stable);
  });

  test('pitch class energy must be 12 bins', () {
    expect(
      () => AnalysisSnapshot(
        timestampMs: 0,
        stableNote: null,
        detectedHz: null,
        confidence: 0,
        amplitudeLinear: 0,
        amplitudeDb: 0,
        gateOpen: false,
        gateThresholdDb: 0,
        noiseFloorDb: 0,
        salienceBySemitone: Float32List(0),
        salienceLowestMidi: 0,
        pitchClassEnergy: Float32List(11),
        spectrum: SpectrumView.empty(),
      ),
      throwsArgumentError,
    );
  });
}
