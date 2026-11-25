import 'package:flutter_test/flutter_test.dart';
import 'package:octune/application/listening_controller.dart';
import 'package:octune/application/listening_state.dart';
import 'package:octune/application/selectors.dart';
import 'package:octune/application/settings_controller.dart';
import 'package:octune/audio/audio_input.dart';
import 'package:octune/audio/permission_service.dart';
import 'package:octune/domain/note_change.dart';
import 'package:octune/domain/note_name.dart';

import '../helpers/rig.dart';
import '../helpers/signals.dart';

ListeningController ctl(Rig r) =>
    r.container.read(listeningProvider.notifier);
ListeningState st(Rig r) => r.container.read(listeningProvider);

void main() {
  test('starts idle', () {
    final r = Rig();
    addTearDown(r.dispose);
    expect(st(r).status, ListeningStatus.idle);
    expect(st(r).snapshot.stableNote, isNull);
    expect(r.input.startCount, 0);
  });

  group('permission', () {
    test('granted: one tap starts listening', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.listening);
      expect(r.input.isRunning, isTrue);
      expect(r.permissionService.requestCount, 0); // no prompt when already granted
    });

    test('denied then granted by the prompt', () async {
      final r = Rig(permission: MicPermissionStatus.denied);
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(r.permissionService.requestCount, 1);
      expect(st(r).status, ListeningStatus.listening);
    });

    test('denied at the prompt: shows denied and never starts the input', () async {
      final r = Rig(
        permission: MicPermissionStatus.denied,
        afterRequest: MicPermissionStatus.denied,
      );
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.permissionDenied);
      expect(r.input.startCount, 0);
    });

    test('a retry after denial asks again', () async {
      final r = Rig(
        permission: MicPermissionStatus.denied,
        afterRequest: MicPermissionStatus.denied,
      );
      addTearDown(r.dispose);
      await ctl(r).toggle();
      r.permissionService.afterRequest = MicPermissionStatus.granted;
      await ctl(r).toggle();
      expect(r.permissionService.requestCount, 2);
      expect(st(r).status, ListeningStatus.listening);
    });

    test('permanently denied: no prompt, settings can be opened', () async {
      final r = Rig(permission: MicPermissionStatus.permanentlyDenied);
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.permissionPermanentlyDenied);
      expect(r.permissionService.requestCount, 0);
      await ctl(r).openPermissionSettings();
      expect(r.permissionService.openSettingsCount, 1);
    });

    test('restricted is reported with an explanation', () async {
      final r = Rig(permission: MicPermissionStatus.restricted);
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.permissionPermanentlyDenied);
      expect(st(r).errorMessage, isNotNull);
    });
  });

  group('listening', () {
    test('a played note appears, then clears in silence', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      await r.play(r.tone(440, seconds: 1.0));
      expect(r.container.read(currentMidiProvider), 69);
      expect(r.container.read(stableNoteProvider)!.cents.abs(), lessThan(5));
      expect(r.container.read(gateOpenProvider), isTrue);
      expect(r.container.read(amplitudeProvider).db, greaterThan(-30));

      await r.play(render(const [Segment(0, 1.2)]));
      expect(r.container.read(currentMidiProvider), isNull);
      expect(r.container.read(gateOpenProvider), isFalse);
    });

    test('silence alone never produces a note', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      await r.play(render(const [Segment(0, 2.0)]));
      expect(r.container.read(currentMidiProvider), isNull);
      expect(st(r).recent.midiNotes, isEmpty);
    });

    test('noteChanges stream carries starts and ends', () async {
      final r = Rig();
      addTearDown(r.dispose);
      final changes = <NoteChange>[];
      ctl(r).noteChanges.listen(changes.add);
      await ctl(r).toggle();
      await r.play(render(const [Segment(0, 0.5), Segment(440, 0.7), Segment(0, 0.8)]));
      await ctl(r).toggle();
      await settle();
      expect(changes.length, 2);
      expect(changes[0].note!.noteName, NoteName.a);
      expect(changes[1].isOff, isTrue);
    });

    test('recent notes are exposed through their selector', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      await r.play(render(const [
        Segment(0, 0.5),
        Segment(440, 0.6),
        Segment(0, 0.5),
        Segment(523.25, 0.6),
      ]));
      expect(r.container.read(recentNotesProvider).midiNotes, equals([69]));
    });

    test('toggle stops: back to idle with a cleared display', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      await r.play(r.tone(440));
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.idle);
      expect(st(r).snapshot.stableNote, isNull);
      expect(r.input.isRunning, isFalse);
    });

    test('selectors only notify when their own value changes', () async {
      final r = Rig();
      addTearDown(r.dispose);
      var noteNotifications = 0;
      var spectrumNotifications = 0;
      r.container.listen(currentMidiProvider, (_, __) => noteNotifications++);
      r.container.listen(spectrumProvider, (_, __) => spectrumNotifications++);
      await ctl(r).toggle();
      await r.play(r.tone(440, seconds: 2.0));
      expect(noteNotifications, 1); // appeared once, then stayed A4
      expect(spectrumNotifications, greaterThan(20)); // redraws every snapshot
    });
  });

  group('failures and interruptions', () {
    test('an input that cannot start gives an error state', () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.input.failOnStart = Exception('Device busy');
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.error);
      expect(st(r).errorMessage, 'Device busy');
      // and a later tap tries again
      r.input.failOnStart = null;
      await ctl(r).toggle();
      expect(st(r).status, ListeningStatus.listening);
      expect(st(r).errorMessage, isNull);
    });

    test('interruption pauses, resume continues', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      await r.play(r.tone(440));
      expect(r.container.read(currentMidiProvider), 69);

      r.input.emit(const AudioInputEvent(AudioInputEventType.interrupted));
      await settle();
      expect(st(r).status, ListeningStatus.interrupted);
      expect(st(r).snapshot.stableNote, isNull); // stale note is cleared

      r.input.emit(const AudioInputEvent(AudioInputEventType.resumed));
      await settle();
      expect(st(r).status, ListeningStatus.listening);
      await r.play(r.tone(330));
      expect(r.container.read(currentMidiProvider), 64);
    });

    test('an input error stops listening and reports why', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      r.input.emit(const AudioInputEvent(AudioInputEventType.error, 'Microphone unplugged'));
      await settle(4);
      expect(st(r).status, ListeningStatus.error);
      expect(st(r).errorMessage, 'Microphone unplugged');
      expect(r.input.isRunning, isFalse);
    });

    test('going to the background releases the microphone', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      r.lifecycle.setForeground(false);
      await settle(4);
      expect(st(r).status, ListeningStatus.idle);
      expect(r.input.isRunning, isFalse);
      r.lifecycle.setForeground(true); // coming back does not auto-start
      await settle();
      expect(st(r).status, ListeningStatus.idle);
    });

    test('disposing the container stops the input', () async {
      final r = Rig();
      await ctl(r).toggle();
      r.dispose();
      await settle(4);
      expect(r.input.isRunning, isFalse);
    });
  });

  group('screen wake lock', () {
    test('on while listening, off when stopped', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(r.wakelock.enabled, isTrue);
      await ctl(r).toggle();
      expect(r.wakelock.enabled, isFalse);
    });

    test('stays off when the setting is off', () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.container.read(settingsProvider.notifier).setKeepScreenAwake(false);
      await ctl(r).toggle();
      expect(r.wakelock.enabled, isFalse);
    });

    test('toggling the setting while listening takes effect', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      expect(r.wakelock.enabled, isTrue);
      r.container.read(settingsProvider.notifier).setKeepScreenAwake(false);
      await settle();
      expect(r.wakelock.enabled, isFalse);
      r.container.read(settingsProvider.notifier).setKeepScreenAwake(true);
      await settle();
      expect(r.wakelock.enabled, isTrue);
    });

    test('released after an error too', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      r.input.emit(const AudioInputEvent(AudioInputEventType.error, 'gone'));
      await settle(4);
      expect(r.wakelock.enabled, isFalse);
    });
  });

  group('settings reach the DSP live', () {
    test('changing A4 while listening changes the reported note', () async {
      final r = Rig();
      addTearDown(r.dispose);
      await ctl(r).toggle();
      r.container.read(settingsProvider.notifier).setA4Hz(415);
      await r.play(r.tone(440));
      final e = r.container.read(stableNoteProvider)!;
      expect('${e.noteName.asciiName}${e.octave}', 'A#4');
    });

    test('settings changed before the first tap are already applied', () async {
      final r = Rig();
      addTearDown(r.dispose);
      r.container.read(listeningProvider); // build the controller
      r.container.read(settingsProvider.notifier).setA4Hz(415);
      await ctl(r).toggle();
      await r.play(r.tone(440));
      expect(r.container.read(currentMidiProvider), 70);
    });
  });
}
