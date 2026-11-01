import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/detector_settings.dart';
import 'package:octune/domain/note_event.dart';
import 'package:octune/domain/note_name.dart';

void main() {
  test('NoteEvent JSON round trip matches the shared schema', () {
    const e = NoteEvent(
      tMs: 1840,
      noteName: NoteName.a,
      octave: 4,
      cents: -7,
      amp: 0.42,
      conf: 0.93,
    );
    final json = e.toJson();
    expect(json['t_ms'], 1840);
    expect(json['note'], 'A');
    expect(json['octave'], 4);
    expect(json['cents'], -7.0);
    expect(json['amp'], 0.42);
    expect(json['conf'], 0.93);
    expect(NoteEvent.fromJson(json), e);
  });

  test('sharps serialize as ASCII and parse back', () {
    const e = NoteEvent(
      tMs: 5,
      noteName: NoteName.fSharp,
      octave: 3,
      cents: 4.5,
      amp: 0.1,
      conf: 0.9,
    );
    expect(e.toJson()['note'], 'F#');
    expect(NoteEvent.fromJson(e.toJson()).noteName, NoteName.fSharp);
    expect(e.midiNumber, 54);
  });

  test('DetectorSettings.validated clamps', () {
    final v = const DetectorSettings(
      a4Hz: 500,
      noiseGate: 2,
      minConfidence: -1,
      minFrequencyHz: 10,
      maxFrequencyHz: 12,
    ).validated();
    expect(v.a4Hz, 466);
    expect(v.noiseGate, 1);
    expect(v.minConfidence, 0);
    expect(v.minFrequencyHz, 20);
    expect(v.maxFrequencyHz, greaterThan(v.minFrequencyHz));
    expect(const DetectorSettings(a4Hz: 300).validated().a4Hz, 415);
  });
}
