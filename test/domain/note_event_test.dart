import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/note_event.dart';
import 'package:octune/domain/note_name.dart';

void main() {
  const NoteEvent sample = NoteEvent(
    tMs: 1840,
    noteName: NoteName.a,
    octave: 4,
    cents: -7,
    amp: 0.42,
    conf: 0.93,
  );

  const String sampleJson =
      '{"t_ms":1840,"note":"A","octave":4,"cents":-7,"amp":0.42,"conf":0.93}';

  test('JSON matches the persistence schema', () {
    expect(jsonEncode(sample.toJson()), sampleJson);
  });

  test('JSON round trip', () {
    final Object? decoded = jsonDecode(sampleJson);
    final NoteEvent restored = NoteEvent.fromJson(
      Map<String, Object?>.from(decoded! as Map<dynamic, dynamic>),
    );
    expect(restored, sample);
    expect(NoteEvent.fromJson(sample.toJson()), sample);
  });

  test('round trip with sharp note name', () {
    const NoteEvent sharp = NoteEvent(
      tMs: 10,
      noteName: NoteName.aSharp,
      octave: 4,
      cents: 0,
      amp: 1,
      conf: 1,
    );
    expect(NoteEvent.fromJson(sharp.toJson()), sharp);
    expect(sharp.toJson()['note'], 'A#');
  });
}
