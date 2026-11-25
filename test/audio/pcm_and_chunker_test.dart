import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/audio/audio_input.dart';
import 'package:octune/audio/frame_chunker.dart';
import 'package:octune/audio/pcm16_decoder.dart';

Uint8List pcm(List<int> samples) {
  final b = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(i * 2, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  group('Pcm16Decoder', () {
    test('decodes known values', () {
      final out = Pcm16Decoder().decode(pcm([0, 32767, -32768, 16384, -16384]));
      expect(out.length, 5);
      expect(out[0], 0);
      expect(out[1], closeTo(0.99997, 1e-5));
      expect(out[2], -1.0);
      expect(out[3], 0.5);
      expect(out[4], -0.5);
    });
    test('a sample split across two chunks is reassembled', () {
      final all = pcm([1000, -2000, 3000, -4000]);
      final d = Pcm16Decoder();
      final a = d.decode(Uint8List.sublistView(all, 0, 3)); // 1.5 samples
      final b = d.decode(Uint8List.sublistView(all, 3, 8));
      expect([...a, ...b].length, 4);
      expect([...a, ...b], equals(Pcm16Decoder().decode(all).toList()));
    });
    test('random split points never change the result', () {
      final rnd = math.Random(5);
      final samples = List<int>.generate(500, (_) => rnd.nextInt(65536) - 32768);
      final all = pcm(samples);
      final expected = Pcm16Decoder().decode(all).toList();
      for (var trial = 0; trial < 20; trial++) {
        final d = Pcm16Decoder();
        final out = <double>[];
        var pos = 0;
        while (pos < all.length) {
          final n = math.min(1 + rnd.nextInt(37), all.length - pos);
          out.addAll(d.decode(Uint8List.sublistView(all, pos, pos + n)));
          pos += n;
        }
        expect(out, equals(expected), reason: 'trial $trial');
      }
    });
    test('an empty chunk keeps the carried byte', () {
      final d = Pcm16Decoder();
      final all = pcm([1234]);
      expect(d.decode(Uint8List.sublistView(all, 0, 1)).length, 0);
      expect(d.decode(Uint8List(0)).length, 0);
      expect(d.decode(Uint8List.sublistView(all, 1, 2))[0], closeTo(1234 / 32768, 1e-9));
    });
    test('reset drops a carried byte', () {
      final d = Pcm16Decoder();
      d.decode(Uint8List.fromList([7]));
      d.reset();
      expect(d.decode(pcm([100])).length, 1);
    });
  });

  group('FrameChunker', () {
    Float32List ramp(int from, int count) =>
        Float32List.fromList([for (var i = 0; i < count; i++) (from + i).toDouble()]);

    test('emits nothing until a full frame is available', () {
      final c = FrameChunker(sampleRate: 44100);
      expect(c.add(ramp(0, 1000)), isEmpty);
      expect(c.pending, 1000);
      final f = c.add(ramp(1000, 1048));
      expect(f.length, 1);
      expect(f.first.samples.length, 2048);
    });
    test('frames overlap by half and are contiguous', () {
      final c = FrameChunker(sampleRate: 44100);
      final frames = c.add(ramp(0, 2048 + 3 * 1024));
      expect(frames.length, 4);
      for (var k = 0; k < frames.length; k++) {
        expect(frames[k].samples[0], k * 1024.0);
        expect(frames[k].samples[2047], k * 1024.0 + 2047);
      }
    });
    test('timestamps follow the sample count, not the wall clock', () {
      final c = FrameChunker(sampleRate: 44100);
      final frames = c.add(ramp(0, 2048 + 2 * 1024));
      expect(frames[0].timestampMs, (2048 * 1000 / 44100).round()); // 46
      expect(frames[1].timestampMs, (3072 * 1000 / 44100).round()); // 70
      expect(frames[2].timestampMs, (4096 * 1000 / 44100).round()); // 93
    });
    test('any way of splitting the input gives the same frames', () {
      final rnd = math.Random(9);
      final total = ramp(0, 20000);
      final expected = FrameChunker(sampleRate: 44100).add(total);
      for (var trial = 0; trial < 20; trial++) {
        final c = FrameChunker(sampleRate: 44100);
        final got = <AudioFrameChunk>[];
        var pos = 0;
        while (pos < total.length) {
          final n = math.min(1 + rnd.nextInt(3000), total.length - pos);
          got.addAll(c.add(Float32List.sublistView(total, pos, pos + n)));
          pos += n;
        }
        expect(got.length, expected.length, reason: 'trial $trial');
        for (var i = 0; i < got.length; i++) {
          expect(got[i].timestampMs, expected[i].timestampMs);
          expect(got[i].samples[0], expected[i].samples[0]);
          expect(got[i].samples[2047], expected[i].samples[2047]);
        }
      }
    });
    test('returned frames are copies', () {
      final c = FrameChunker(sampleRate: 44100);
      final frames = c.add(ramp(0, 4096));
      frames[0].samples[0] = 999;
      expect(frames[1].samples[0], 1024.0);
    });
    test('handles very large blocks', () {
      final c = FrameChunker(sampleRate: 48000);
      final frames = c.add(ramp(0, 100000));
      expect(frames.length, (100000 - 2048) ~/ 1024 + 1);
      expect(frames.first.sampleRate, 48000);
    });
    test('reset starts a new timeline', () {
      final c = FrameChunker(sampleRate: 44100);
      c.add(ramp(0, 5000));
      c.reset();
      expect(c.pending, 0);
      expect(c.add(ramp(0, 2048)).first.timestampMs, 46);
    });
  });
}
