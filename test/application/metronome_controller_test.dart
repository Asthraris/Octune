import 'package:flutter_test/flutter_test.dart';
import 'package:octune/application/listening_controller.dart';
import 'package:octune/application/metronome_controller.dart';
import 'package:octune/application/selectors.dart';
import 'package:octune/data/settings_codec.dart';
import 'package:octune/domain/metronome_settings.dart';

import '../helpers/rig.dart';

MetronomeController ctl(Rig r) => r.container.read(metronomeProvider.notifier);
MetronomeState st(Rig r) => r.container.read(metronomeProvider);

void main() {
  test('starts stopped with default settings', () {
    final r = Rig();
    addTearDown(r.dispose);
    expect(st(r).running, isFalse);
    expect(st(r).settings, const MetronomeSettings());
  });

  test('stored settings are loaded', () {
    final r = Rig(storeData: {
      kMetronomeSettingsKey: encodeMetronome(const MetronomeSettings(bpm: 133, beatsPerBar: 7)),
    });
    addTearDown(r.dispose);
    expect(st(r).settings.bpm, 133);
    expect(st(r).settings.beatsPerBar, 7);
  });

  test('start and stop drive the engine', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).start();
    expect(st(r).running, isTrue);
    expect(r.metronome.isRunning, isTrue);
    expect(r.metronome.settings, const MetronomeSettings());
    await ctl(r).stop();
    expect(st(r).running, isFalse);
    expect(r.metronome.isRunning, isFalse);
  });

  test('toggle', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).toggle();
    expect(st(r).running, isTrue);
    await ctl(r).toggle();
    expect(st(r).running, isFalse);
  });

  test('bpm is clamped to 20..240', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).setBpm(999);
    expect(st(r).settings.bpm, 240);
    await ctl(r).setBpm(3);
    expect(st(r).settings.bpm, 20);
    await ctl(r).nudgeBpm(5);
    expect(st(r).settings.bpm, 25);
    await ctl(r).nudgeBpm(-100);
    expect(st(r).settings.bpm, 20);
  });

  test('settings changes reach a running engine, not a stopped one', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).setBpm(90); // stopped: engine untouched
    expect(r.metronome.history, isEmpty);
    await ctl(r).start();
    await ctl(r).setBpm(120);
    await ctl(r).setTimeSignature(3, 4);
    await ctl(r).setVolume(0.3);
    expect(r.metronome.settings!.bpm, 120);
    expect(r.metronome.settings!.beatsPerBar, 3);
    expect(r.metronome.settings!.volume, 0.3);
  });

  test('tap tempo follows the taps', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.clock.advance(1000);
    await ctl(r).tapTempo();
    expect(st(r).settings.bpm, 100); // one tap: unchanged
    for (var i = 0; i < 4; i++) {
      r.clock.advance(500);
      await ctl(r).tapTempo();
    }
    expect(st(r).settings.bpm, 120);
  });

  test('tap tempo outside the range is clamped', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).tapTempo();
    r.clock.advance(100); // 600 bpm
    await ctl(r).tapTempo();
    expect(st(r).settings.bpm, 240);
  });

  test('beats update the state while running', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.container.listen(metronomeProvider, (_, __) {});
    await ctl(r).start();
    await settle();
    expect(st(r).lastBeat?.beatIndex, 0);
    r.metronome.advance(1300);
    await settle();
    expect(st(r).lastBeat?.beatIndex, greaterThanOrEqualTo(2));
    await ctl(r).stop();
    expect(st(r).lastBeat, isNull);
  });

  test('persists after flush', () async {
    final r = Rig();
    addTearDown(r.dispose);
    await ctl(r).setBpm(88);
    await ctl(r).setSubdivision(2);
    expect(r.store.writeCount, 0);
    await ctl(r).flush();
    final saved = decodeMetronome(r.store.read(kMetronomeSettingsKey));
    expect(saved.bpm, 88);
    expect(saved.subdivision, 2);
  });

  test('a failing engine reports an error and stays stopped', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.metronome.failOnStart = Exception('audio device unavailable');
    await ctl(r).start();
    expect(st(r).running, isFalse);
    expect(st(r).errorMessage, contains('audio device unavailable'));
  });

  test('headphones hint appears only while listening AND clicking', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.container.listen(headphonesHintProvider, (_, __) {});
    expect(r.container.read(headphonesHintProvider), isFalse);
    await ctl(r).start();
    expect(r.container.read(headphonesHintProvider), isFalse);
    await r.container.read(listeningProvider.notifier).toggle();
    expect(r.container.read(headphonesHintProvider), isTrue);
    await ctl(r).stop();
    expect(r.container.read(headphonesHintProvider), isFalse);
  });

  test('disposing stops the engine', () async {
    final r = Rig();
    await ctl(r).start();
    r.dispose();
    await settle();
    expect(r.metronome.isRunning, isFalse);
  });
}
