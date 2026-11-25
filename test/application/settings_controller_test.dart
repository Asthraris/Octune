import 'package:flutter_test/flutter_test.dart';
import 'package:octune/application/listening_controller.dart';
import 'package:octune/application/settings_controller.dart';
import 'package:octune/data/settings_codec.dart';
import 'package:octune/domain/detection_preset.dart';
import 'package:octune/domain/detector_settings.dart';
import 'package:octune/domain/note_name.dart';
import 'package:octune/domain/ui_settings.dart';

import '../helpers/rig.dart';
import '../helpers/signals.dart';

SettingsController ctl(Rig r) => r.container.read(settingsProvider.notifier);
SettingsState st(Rig r) => r.container.read(settingsProvider);

void main() {
  test('defaults when nothing is stored', () {
    final r = Rig();
    addTearDown(r.dispose);
    expect(st(r).detector, const DetectorSettings());
    expect(st(r).ui, const UiSettings());
    expect(st(r).preset, DetectionPreset.fullRange);
  });

  test('stored settings are loaded', () {
    final r = Rig(storeData: {
      kDetectorSettingsKey: encodeDetector(const DetectorSettings(a4Hz: 432)),
      kUiSettingsKey: encodeUi(const UiSettings(showCents: false)),
    });
    addTearDown(r.dispose);
    expect(st(r).detector.a4Hz, 432);
    expect(st(r).ui.showCents, isFalse);
  });

  test('corrupt stored data falls back to defaults', () {
    final r = Rig(storeData: {kDetectorSettingsKey: '{{{', kUiSettingsKey: 'x'});
    addTearDown(r.dispose);
    expect(st(r).detector, const DetectorSettings());
    expect(st(r).ui, const UiSettings());
  });

  test('values are clamped', () {
    final r = Rig();
    addTearDown(r.dispose);
    ctl(r).setA4Hz(500);
    expect(st(r).detector.a4Hz, 466);
    ctl(r).setA4Hz(100);
    expect(st(r).detector.a4Hz, 415);
    ctl(r).setNoiseGate(7);
    expect(st(r).detector.noiseGate, 1);
    ctl(r).setMinConfidence(-1);
    expect(st(r).detector.minConfidence, 0);
  });

  test('presets set the range and are recognised', () {
    final r = Rig();
    addTearDown(r.dispose);
    ctl(r).setDetectionPreset(DetectionPreset.flute);
    expect(st(r).detector.minFrequencyHz, 250);
    expect(st(r).detector.maxFrequencyHz, 2200);
    expect(st(r).preset, DetectionPreset.flute);
    ctl(r).setFrequencyRange(100, 900);
    expect(st(r).preset, isNull);
  });

  test('ui settings update', () {
    final r = Rig();
    addTearDown(r.dispose);
    ctl(r).setAccidentalPreference(AccidentalPreference.flats);
    ctl(r).setShowCents(false);
    ctl(r).setKeepScreenAwake(false);
    ctl(r).setReduceMotion(true);
    expect(st(r).ui.accidentalPreference, AccidentalPreference.flats);
    expect(st(r).ui.showCents, isFalse);
    expect(st(r).ui.keepScreenAwake, isFalse);
    expect(st(r).ui.reduceMotion, isTrue);
  });

  group('persistence', () {
    test('nothing is written until flush, then everything pending is', () async {
      final r = Rig();
      addTearDown(r.dispose);
      ctl(r).setA4Hz(432);
      ctl(r).setShowCents(false);
      expect(r.store.writeCount, 0);
      await ctl(r).flush();
      expect(r.store.writeCount, 2);
      expect(decodeDetector(r.store.read(kDetectorSettingsKey)).a4Hz, 432);
      expect(decodeUi(r.store.read(kUiSettingsKey)).showCents, isFalse);
    });

    test('many slider changes are written once', () async {
      final r = Rig();
      addTearDown(r.dispose);
      for (var i = 0; i < 50; i++) {
        ctl(r).setNoiseGate(i / 50);
      }
      await ctl(r).flush();
      expect(r.store.writeCount, 1);
      expect(decodeDetector(r.store.read(kDetectorSettingsKey)).noiseGate,
          closeTo(0.98, 1e-9));
    });

    test('the debounce timer writes by itself', () async {
      final r = Rig();
      addTearDown(r.dispose);
      ctl(r).setA4Hz(435);
      await Future<void>.delayed(SettingsController.saveDelay + const Duration(milliseconds: 80));
      expect(decodeDetector(r.store.read(kDetectorSettingsKey)).a4Hz, 435);
    });

    test('disposing flushes pending changes', () async {
      final r = Rig();
      ctl(r).setA4Hz(438);
      r.dispose();
      await settle(3);
      expect(decodeDetector(r.store.read(kDetectorSettingsKey)).a4Hz, 438);
    });

    test('a fresh container sees what was saved', () async {
      final a = Rig();
      ctl(a).setDetectionPreset(DetectionPreset.voice);
      ctl(a).setAccidentalPreference(AccidentalPreference.flats);
      await ctl(a).flush();
      final b = Rig(storeData: a.store.data);
      addTearDown(b.dispose);
      a.dispose();
      expect(st(b).preset, DetectionPreset.voice);
      expect(st(b).ui.accidentalPreference, AccidentalPreference.flats);
    });

    test('unchanged values write nothing', () async {
      final r = Rig();
      addTearDown(r.dispose);
      ctl(r).setA4Hz(440); // already 440
      ctl(r).setShowCents(true); // already true
      await ctl(r).flush();
      expect(r.store.writeCount, 0);
    });
  });

  test('resetToDefaults restores and persists', () async {
    final r = Rig();
    addTearDown(r.dispose);
    ctl(r).setA4Hz(432);
    ctl(r).setShowCents(false);
    ctl(r).resetToDefaults();
    await ctl(r).flush();
    expect(st(r).detector, const DetectorSettings());
    expect(st(r).ui, const UiSettings());
    expect(decodeDetector(r.store.read(kDetectorSettingsKey)), const DetectorSettings());
  });

  group('gate threshold drag', () {
    test('sets the DSP threshold and stores the equivalent noiseGate', () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.container.read(listeningProvider); // controller listens to settings
      await listenAndCalibrate(r);
      final floor = r.analyzer.noiseFloorDb;
      expect(floor, closeTo(-50, 4));
      final g = ctl(r).setGateThresholdDb(floor + 14);
      expect(g, closeTo(0.5, 1e-6));
      expect(st(r).detector.noiseGate, closeTo(0.5, 1e-6));
      expect(r.analyzer.gateThresholdDb, closeTo(floor + 14, 1e-6));
      await ctl(r).flush();
      expect(decodeDetector(r.store.read(kDetectorSettingsKey)).noiseGate, closeTo(0.5, 1e-6));
    });

    test('the controller pushes slider changes to the DSP', () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.container.read(listeningProvider);
      ctl(r).setNoiseGate(1.0);
      expect(r.analyzer.settings.noiseGate, 1.0);
      ctl(r).setDetectionPreset(DetectionPreset.guitar);
      expect(r.analyzer.settings.minFrequencyHz, 75);
    });
  });
}

/// Starts listening in a quiet room (about -50 dBFS of noise) so the gate
/// learns a realistic floor.
Future<void> listenAndCalibrate(Rig r) async {
  await r.container.read(listeningProvider.notifier).toggle();
  await r.play(whiteNoise(n: 44100, amp: 0.00548));
}
