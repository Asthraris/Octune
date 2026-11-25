import 'package:flutter_test/flutter_test.dart';
import 'package:octune/data/settings_codec.dart';
import 'package:octune/data/settings_store.dart';
import 'package:octune/domain/detector_settings.dart';
import 'package:octune/domain/metronome_settings.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/ui_settings.dart';

void main() {
  group('detector', () {
    test('round trip', () {
      const s = DetectorSettings(
          a4Hz: 432, noiseGate: 0.6, minConfidence: 0.9, minFrequencyHz: 80, maxFrequencyHz: 1200);
      expect(decodeDetector(encodeDetector(s)), s);
    });
    test('missing, corrupt or wrong-typed data gives defaults', () {
      expect(decodeDetector(null), const DetectorSettings());
      expect(decodeDetector('not json'), const DetectorSettings());
      expect(decodeDetector('[1,2]'), const DetectorSettings());
      expect(decodeDetector('{"a4Hz":"loud","noiseGate":null}'), const DetectorSettings());
    });
    test('out-of-range values are clamped', () {
      final s = decodeDetector('{"a4Hz":9000,"noiseGate":5,"minConfidence":-3}');
      expect(s.a4Hz, 466);
      expect(s.noiseGate, 1);
      expect(s.minConfidence, 0);
    });
    test('partial data keeps the rest at defaults', () {
      final s = decodeDetector('{"a4Hz":435}');
      expect(s.a4Hz, 435);
      expect(s.noiseGate, const DetectorSettings().noiseGate);
    });
  });

  group('ui', () {
    test('round trip', () {
      const s = UiSettings(
          accidentalPreference: AccidentalPreference.flats,
          showCents: false,
          keepScreenAwake: false,
          reduceMotion: true);
      expect(decodeUi(encodeUi(s)), s);
    });
    test('unknown enum value and corrupt data give defaults', () {
      expect(decodeUi('{"accidentals":"quarter-tones"}').accidentalPreference,
          AccidentalPreference.sharps);
      expect(decodeUi('###'), const UiSettings());
    });
  });

  group('metronome', () {
    test('round trip', () {
      const s = MetronomeSettings(
          bpm: 133, beatsPerBar: 7, beatUnit: 8, accentFirstBeat: false, subdivision: 2, volume: 0.4);
      expect(decodeMetronome(encodeMetronome(s)), s);
    });
    test('out-of-range values are clamped', () {
      final s = decodeMetronome('{"bpm":5000,"beatsPerBar":99,"volume":9}');
      expect(s.bpm, 240);
      expect(s.beatsPerBar, 12);
      expect(s.volume, 1);
    });
    test('corrupt data gives defaults', () {
      expect(decodeMetronome('{'), const MetronomeSettings());
    });
  });

  test('InMemorySettingsStore reads, writes and removes', () async {
    final store = InMemorySettingsStore({'a': '1'});
    expect(store.read('a'), '1');
    await store.write('b', '2');
    expect(store.read('b'), '2');
    await store.remove('a');
    expect(store.read('a'), isNull);
    expect(store.writeCount, 1);
  });
}
