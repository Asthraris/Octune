import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/audio/bar_renderer.dart';
import 'package:octune/audio/beat_tracker.dart';
import 'package:octune/audio/fake_metronome_engine.dart';
import 'package:octune/audio/pcm16_decoder.dart';
import 'package:octune/audio/wav_encoder.dart';
import 'package:octune/domain/beat_event.dart';
import 'package:octune/domain/metronome_settings.dart';

double peak(Float32List s, int from, int to) {
  var m = 0.0;
  for (var i = from; i < to; i++) {
    m = math.max(m, s[i].abs());
  }
  return m;
}

void main() {
  group('BarRenderer', () {
    test('120 bpm 4/4: clicks land exactly on the beats', () {
      final bar = BarRenderer.render(const MetronomeSettings(bpm: 120));
      expect(bar.length, 88200);
      expect(bar.beatStartSamples, equals([0, 22050, 44100, 66150]));
      for (final start in bar.beatStartSamples) {
        expect(peak(bar.samples, start, start + 200), greaterThan(0.3));
      }
    });
    test('the buffer is silent between clicks', () {
      final bar = BarRenderer.render(const MetronomeSettings(bpm: 120));
      expect(peak(bar.samples, 3000, 22000), 0);
      expect(peak(bar.samples, 25000, 44000), 0);
    });
    test('accent is louder than a normal beat', () {
      final bar = BarRenderer.render(const MetronomeSettings(bpm: 120));
      expect(peak(bar.samples, 0, 400), greaterThan(peak(bar.samples, 22050, 22450)));
    });
    test('without accent every beat is equally loud', () {
      final bar = BarRenderer.render(
          const MetronomeSettings(bpm: 120, accentFirstBeat: false));
      expect(peak(bar.samples, 0, 400), closeTo(peak(bar.samples, 22050, 22450), 0.02));
    });
    test('subdivision adds quieter clicks halfway through each beat', () {
      final bar = BarRenderer.render(const MetronomeSettings(bpm: 120, subdivision: 2));
      final sub = peak(bar.samples, 11025, 11425);
      expect(sub, greaterThan(0.1));
      expect(sub, lessThan(peak(bar.samples, 22050, 22450)));
    });
    test('never clips', () {
      for (final s in [
        const MetronomeSettings(bpm: 240, subdivision: 4),
        const MetronomeSettings(bpm: 20, beatsPerBar: 12),
        const MetronomeSettings(bpm: 97, beatsPerBar: 7, subdivision: 3),
      ]) {
        expect(peak(BarRenderer.render(s).samples, 0, BarRenderer.render(s).length),
            lessThanOrEqualTo(1.0));
      }
    });
    test('bar length is within half a sample of the exact value', () {
      for (final bpm in [20, 63, 97, 133, 187, 240]) {
        final bar = BarRenderer.render(MetronomeSettings(bpm: bpm));
        final exact = 44100 * 60.0 / bpm * 4;
        expect((bar.length - exact).abs(), lessThanOrEqualTo(0.5), reason: '$bpm');
      }
    });
    test('drift over one minute is far below 5 ms', () {
      for (final bpm in [63, 97, 133, 187]) {
        final bar = BarRenderer.render(MetronomeSettings(bpm: bpm));
        final exact = 44100 * 60.0 / bpm * 4;
        final bars = 60000 / (exact / 44.1);
        final driftMs = (bar.length - exact).abs() * bars / 44.1;
        expect(driftMs, lessThan(1.0), reason: '$bpm bpm: $driftMs ms');
      }
    });
    test('clicks near the end of the bar wrap around (seamless loop)', () {
      final bar = BarRenderer.render(
          const MetronomeSettings(bpm: 240, beatsPerBar: 1, subdivision: 4));
      expect(bar.length, 11025);
      expect(bar.samples.length, 11025);
    });
    test('a one-beat bar is valid', () {
      final bar = BarRenderer.render(const MetronomeSettings(beatsPerBar: 1, bpm: 60));
      expect(bar.length, 44100);
      expect(bar.beatStartSamples, equals([0]));
    });
  });

  group('WavEncoder', () {
    test('writes a valid 16-bit mono header', () {
      final wav = WavEncoder.pcm16Mono(Float32List(100), 44100);
      expect(wav.length, 44 + 200);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      final b = ByteData.sublistView(wav);
      expect(b.getUint32(4, Endian.little), 36 + 200);
      expect(b.getUint16(20, Endian.little), 1); // PCM
      expect(b.getUint16(22, Endian.little), 1); // mono
      expect(b.getUint32(24, Endian.little), 44100);
      expect(b.getUint32(28, Endian.little), 88200);
      expect(b.getUint16(34, Endian.little), 16);
      expect(b.getUint32(40, Endian.little), 200);
    });
    test('samples survive a round trip and clip at full scale', () {
      final src = Float32List.fromList([0, 0.5, -0.5, 1, -1, 2, -2]);
      final wav = WavEncoder.pcm16Mono(src, 44100);
      final back = Pcm16Decoder().decode(Uint8List.sublistView(wav, 44));
      expect(back[1], closeTo(0.5, 1e-4));
      expect(back[2], closeTo(-0.5, 1e-4));
      expect(back[3], closeTo(1, 1e-4));
      expect(back[5], closeTo(1, 1e-4)); // clipped
      expect(back[6], lessThanOrEqualTo(-0.99));
    });
  });

  group('BeatTracker', () {
    // 100 bpm, 4/4: beat = 600 ms, loop = 2400 ms.
    List<(double, BeatEvent)> simulate({
      required double pollMs,
      required double durationMs,
      double reportEveryMs = 0,
      bool wrap = true,
      bool stuck = false,
      BeatTracker? tracker,
    }) {
      final t = tracker ??
          BeatTracker(beatsPerBar: 4, loopLengthMs: 2400, lookaheadMs: 120);
      final out = <(double, BeatEvent)>[];
      var lastReported = 0.0;
      for (var now = 0.0; now <= durationMs; now += pollMs) {
        if (reportEveryMs == 0 || now - lastReported >= reportEveryMs) {
          lastReported = now;
        }
        final audio = reportEveryMs == 0 ? now : lastReported;
        final pos = stuck ? 0.0 : (wrap ? audio % 2400 : audio);
        for (final e in t.update(positionMs: pos, nowMs: now)) {
          out.add((now, e));
        }
      }
      return out;
    }

    test('beats come out in order, once each, at exact beat times', () {
      final events = simulate(pollMs: 8, durationMs: 9000);
      for (var i = 0; i < events.length; i++) {
        expect(events[i].$2.beatIndex, i);
        expect(events[i].$2.scheduledAtMonotonicMs, closeTo(i * 600, 1e-6));
      }
      expect(events.length, greaterThanOrEqualTo(15));
    });
    test('beats are announced up to 120 ms ahead, never earlier', () {
      final events = simulate(pollMs: 8, durationMs: 6000);
      for (final (emittedAt, e) in events.skip(1)) {
        final ahead = e.scheduledAtMonotonicMs - emittedAt;
        expect(ahead, lessThanOrEqualTo(120 + 1e-9));
        expect(ahead, greaterThan(120 - 8 - 1e-9));
      }
    });
    test('works when the player keeps counting instead of wrapping', () {
      final events = simulate(pollMs: 8, durationMs: 7000, wrap: false);
      for (var i = 0; i < events.length; i++) {
        expect(events[i].$2.beatIndex, i);
        expect(events[i].$2.scheduledAtMonotonicMs, closeTo(i * 600, 1e-6));
      }
    });
    test('coarse position steps are smoothed by extrapolation', () {
      final events = simulate(pollMs: 8, durationMs: 7000, reportEveryMs: 46);
      for (var i = 0; i < events.length; i++) {
        expect(events[i].$2.beatIndex, i);
        // true beat time is i * 600; allow the coarse report granularity
        expect(events[i].$2.scheduledAtMonotonicMs, closeTo(i * 600, 46));
      }
    });
    test('a position that never advances falls back to the clock', () {
      final events = simulate(pollMs: 8, durationMs: 4000, stuck: true);
      expect(events.length, greaterThanOrEqualTo(6));
      for (var i = 0; i < events.length; i++) {
        expect(events[i].$2.beatIndex, i);
        expect(events[i].$2.scheduledAtMonotonicMs, closeTo(i * 600, 1e-6));
      }
    });
    test('accent on beat 1 of each bar, sides alternate', () {
      final events = simulate(pollMs: 8, durationMs: 6000);
      for (final (_, e) in events) {
        expect(e.beatInBar, e.beatIndex % 4);
        expect(e.isAccent, e.beatInBar == 0);
        expect(e.side, e.beatIndex.isEven ? SwingSide.left : SwingSide.right);
      }
    });
    test('no accent when disabled', () {
      final t = BeatTracker(
          beatsPerBar: 4, loopLengthMs: 2400, accentFirstBeat: false);
      expect(simulate(pollMs: 8, durationMs: 3000, tracker: t).any((e) => e.$2.isAccent),
          isFalse);
    });
    test('the first update announces beat 0 straight away', () {
      final t = BeatTracker(beatsPerBar: 4, loopLengthMs: 2400);
      final first = t.update(positionMs: 0, nowMs: 1000);
      expect(first.length, 1);
      expect(first.first.beatIndex, 0);
      expect(first.first.scheduledAtMonotonicMs, closeTo(1000, 1e-9));
    });
    test('fast tempo: several beats can be due at once', () {
      // 240 bpm: beat = 250 ms, lookahead 120 ms
      final t = BeatTracker(beatsPerBar: 4, loopLengthMs: 1000, lookaheadMs: 400);
      final first = t.update(positionMs: 0, nowMs: 0);
      expect(first.map((e) => e.beatIndex).toList(), equals([0, 1]));
    });
    test('time never runs backwards', () {
      final t = BeatTracker(beatsPerBar: 4, loopLengthMs: 2400);
      var last = -1;
      for (var now = 0.0; now < 5000; now += 8) {
        // jittery reports that sometimes lag behind the clock
        final pos = (now - (now.toInt() % 3 == 0 ? 20 : 0)).clamp(0.0, 1e9) % 2400;
        for (final e in t.update(positionMs: pos, nowMs: now)) {
          expect(e.beatIndex, last + 1);
          last = e.beatIndex;
        }
      }
    });
  });

  group('FakeMetronomeEngine', () {
    test('start announces beat 0; time produces the following beats', () async {
      final engine = FakeMetronomeEngine();
      final beats = <BeatEvent>[];
      engine.beats.listen(beats.add);
      await engine.start(const MetronomeSettings(bpm: 100));
      engine.advance(2500);
      await Future<void>.delayed(Duration.zero);
      expect(engine.isRunning, isTrue);
      expect(beats.map((b) => b.beatIndex).take(5).toList(), equals([0, 1, 2, 3, 4]));
      expect(beats[4].scheduledAtMonotonicMs, closeTo(2400, 1));
      expect(beats[4].isAccent, isTrue);
    });
    test('changing bpm restarts from beat 0; changing volume does not', () async {
      final engine = FakeMetronomeEngine();
      final beats = <BeatEvent>[];
      engine.beats.listen(beats.add);
      await engine.start(const MetronomeSettings(bpm: 100));
      engine.advance(1300);
      await Future<void>.delayed(Duration.zero);
      final before = beats.length;
      await engine.updateSettings(const MetronomeSettings(bpm: 100, volume: 0.3));
      engine.advance(10);
      await Future<void>.delayed(Duration.zero);
      expect(beats.length, before); // no restart, no duplicate beat 0

      await engine.updateSettings(const MetronomeSettings(bpm: 120));
      await Future<void>.delayed(Duration.zero);
      expect(beats.last.beatIndex, 0);
      expect(beats.length, before + 1);
    });
    test('stop silences the engine', () async {
      final engine = FakeMetronomeEngine();
      final beats = <BeatEvent>[];
      engine.beats.listen(beats.add);
      await engine.start(const MetronomeSettings());
      await engine.stop();
      final n = beats.length;
      engine.advance(5000);
      await Future<void>.delayed(Duration.zero);
      expect(beats.length, n);
      expect(engine.isRunning, isFalse);
    });
  });
}
