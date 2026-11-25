import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/bpm_tap_calculator.dart';
import 'package:octune/domain/detection_preset.dart';
import 'package:octune/domain/detector_settings.dart';
import 'package:octune/domain/metronome_settings.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/recent_notes.dart';

void main() {
  group('MetronomeSettings', () {
    test('defaults', () {
      const s = MetronomeSettings();
      expect(s.bpm, 100);
      expect(s.beatsPerBar, 4);
      expect(s.accentFirstBeat, isTrue);
      expect(s.beatIntervalMs, 600);
    });
    test('validated clamps every field', () {
      final v = const MetronomeSettings(
        bpm: 999,
        beatsPerBar: 50,
        beatUnit: 7,
        subdivision: 9,
        volume: 3,
      ).validated();
      expect(v.bpm, 240);
      expect(v.beatsPerBar, 12);
      expect(v.beatUnit, 4);
      expect(v.subdivision, 4);
      expect(v.volume, 1);
      final lo = const MetronomeSettings(bpm: 1, beatsPerBar: 0, subdivision: 0, volume: -1)
          .validated();
      expect(lo.bpm, 20);
      expect(lo.beatsPerBar, 1);
      expect(lo.subdivision, 1);
      expect(lo.volume, 0);
    });
    test('sameClickPatternAs ignores volume and unit only', () {
      const a = MetronomeSettings();
      expect(a.sameClickPatternAs(a.copyWith(volume: 0.2)), isTrue);
      expect(a.sameClickPatternAs(a.copyWith(beatUnit: 8)), isTrue);
      expect(a.sameClickPatternAs(a.copyWith(bpm: 101)), isFalse);
      expect(a.sameClickPatternAs(a.copyWith(beatsPerBar: 3)), isFalse);
      expect(a.sameClickPatternAs(a.copyWith(accentFirstBeat: false)), isFalse);
      expect(a.sameClickPatternAs(a.copyWith(subdivision: 2)), isFalse);
    });
    test('value equality', () {
      expect(const MetronomeSettings(), const MetronomeSettings());
      expect(const MetronomeSettings() == const MetronomeSettings(bpm: 90), isFalse);
    });
  });

  group('BpmTapCalculator', () {
    test('needs two taps', () {
      final t = BpmTapCalculator();
      expect(t.tap(0), isNull);
      expect(t.tap(500), closeTo(120, 1e-9));
    });
    test('averages the last four intervals', () {
      final t = BpmTapCalculator();
      t.tap(0);
      t.tap(600);
      t.tap(1200);
      t.tap(1800);
      expect(t.tap(2400), closeTo(100, 1e-9));
    });
    test('old taps drop out of the average', () {
      final t = BpmTapCalculator();
      var now = 0;
      t.tap(now);
      // a slow start (1000 ms), then steady 500 ms taps
      now += 1000;
      t.tap(now);
      double? bpm;
      for (var i = 0; i < 6; i++) {
        now += 500;
        bpm = t.tap(now);
      }
      expect(bpm, closeTo(120, 1e-9)); // the 1000 ms interval has aged out
    });
    test('a pause of more than 2 s starts over', () {
      final t = BpmTapCalculator();
      t.tap(0);
      t.tap(500);
      expect(t.tap(5000), isNull);
      expect(t.tap(5400), closeTo(150, 1e-9));
    });
    test('duplicate or backwards taps are ignored', () {
      final t = BpmTapCalculator();
      t.tap(1000);
      t.tap(1500);
      expect(t.tap(1500), closeTo(120, 1e-9));
      expect(t.tap(1400), closeTo(120, 1e-9));
    });
    test('reset', () {
      final t = BpmTapCalculator();
      t.tap(0);
      t.tap(500);
      t.reset();
      expect(t.tap(600), isNull);
    });
  });

  group('RecentNotes', () {
    RecentNotes feed(List<int?> midis, {int max = 3}) {
      var r = RecentNotes.empty(maxCount: max);
      for (final m in midis) {
        r = r.update(m);
      }
      return r;
    }

    test('C4, C4, A4, E5 -> recent [A4, C4] while E5 sounds', () {
      expect(feed([60, 60, 69, 76]).midiNotes, equals([69, 60]));
    });
    test('silence does not push; the released note joins the list', () {
      final r = feed([60, 69, null, null, null]);
      expect(r.midiNotes, equals([69, 60]));
    });
    test('the same note again after silence is a repeat', () {
      expect(feed([60, null, 60]).midiNotes, isEmpty);
      expect(feed([60, 69, null, 69]).midiNotes, equals([60]));
    });
    test('keeps at most maxCount', () {
      expect(feed([60, 62, 64, 65, 67, 69, 71], max: 3).midiNotes,
          equals([69, 67, 65]));
      expect(feed([60, 62, 64, 65, null], max: 2).midiNotes, equals([65, 64]));
    });
    test('notes map to readable names', () {
      final n = feed([60, 69, 76]).notes;
      expect(n.map((e) => '${e.noteName.asciiName}${e.octave}').toList(),
          equals(['A4', 'C4']));
    });
    test('value equality', () {
      expect(feed([60, 62]), feed([60, 62]));
      expect(feed([60, 62]) == feed([60, 64]), isFalse);
    });
  });

  group('DetectionPreset', () {
    test('applyTo and matching round trip', () {
      for (final p in DetectionPreset.values) {
        final s = p.applyTo(const DetectorSettings());
        expect(s.minFrequencyHz, p.minHz);
        expect(s.maxFrequencyHz, p.maxHz);
        expect(DetectionPreset.matching(s), p);
      }
    });
    test('custom ranges match nothing', () {
      expect(
          DetectionPreset.matching(const DetectorSettings(minFrequencyHz: 100, maxFrequencyHz: 900)),
          isNull);
    });
    test('every preset is valid after clamping', () {
      for (final p in DetectionPreset.values) {
        final s = p.applyTo(const DetectorSettings()).validated();
        expect(s.minFrequencyHz, p.minHz);
        expect(s.maxFrequencyHz, p.maxHz);
      }
    });
  });
}
