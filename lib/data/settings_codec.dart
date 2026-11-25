import 'dart:convert';

import '../domain/detector_settings.dart';
import '../domain/metronome_settings.dart';
import '../domain/note_name.dart';
import '../domain/ui_settings.dart';

/// Storage keys. The suffix is a schema version: bump it if a format
/// changes incompatibly.
const String kDetectorSettingsKey = 'octune.detector.v1';
const String kUiSettingsKey = 'octune.ui.v1';
const String kMetronomeSettingsKey = 'octune.metronome.v1';

Map<String, dynamic>? _decodeMap(String? text) {
  if (text == null) return null;
  try {
    final value = jsonDecode(text);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
int? _int(Object? v) => v is num && v.isFinite ? v.toInt() : null;
bool? _bool(Object? v) => v is bool ? v : null;

String encodeDetector(DetectorSettings s) => jsonEncode({
      'a4Hz': s.a4Hz,
      'noiseGate': s.noiseGate,
      'minConfidence': s.minConfidence,
      'minFrequencyHz': s.minFrequencyHz,
      'maxFrequencyHz': s.maxFrequencyHz,
    });

/// Missing, corrupt or out-of-range data falls back to defaults and is clamped.
DetectorSettings decodeDetector(String? text) {
  final m = _decodeMap(text);
  if (m == null) return const DetectorSettings();
  const d = DetectorSettings();
  return DetectorSettings(
    a4Hz: _num(m['a4Hz']) ?? d.a4Hz,
    noiseGate: _num(m['noiseGate']) ?? d.noiseGate,
    minConfidence: _num(m['minConfidence']) ?? d.minConfidence,
    minFrequencyHz: _num(m['minFrequencyHz']) ?? d.minFrequencyHz,
    maxFrequencyHz: _num(m['maxFrequencyHz']) ?? d.maxFrequencyHz,
  ).validated();
}

String encodeUi(UiSettings s) => jsonEncode({
      'accidentals': s.accidentalPreference.name,
      'showCents': s.showCents,
      'keepScreenAwake': s.keepScreenAwake,
      'reduceMotion': s.reduceMotion,
    });

UiSettings decodeUi(String? text) {
  final m = _decodeMap(text);
  if (m == null) return const UiSettings();
  const d = UiSettings();
  return UiSettings(
    accidentalPreference: AccidentalPreference.values.firstWhere(
      (v) => v.name == m['accidentals'],
      orElse: () => d.accidentalPreference,
    ),
    showCents: _bool(m['showCents']) ?? d.showCents,
    keepScreenAwake: _bool(m['keepScreenAwake']) ?? d.keepScreenAwake,
    reduceMotion: _bool(m['reduceMotion']) ?? d.reduceMotion,
  );
}

String encodeMetronome(MetronomeSettings s) => jsonEncode({
      'bpm': s.bpm,
      'beatsPerBar': s.beatsPerBar,
      'beatUnit': s.beatUnit,
      'accentFirstBeat': s.accentFirstBeat,
      'subdivision': s.subdivision,
      'volume': s.volume,
    });

MetronomeSettings decodeMetronome(String? text) {
  final m = _decodeMap(text);
  if (m == null) return const MetronomeSettings();
  const d = MetronomeSettings();
  return MetronomeSettings(
    bpm: _int(m['bpm']) ?? d.bpm,
    beatsPerBar: _int(m['beatsPerBar']) ?? d.beatsPerBar,
    beatUnit: _int(m['beatUnit']) ?? d.beatUnit,
    accentFirstBeat: _bool(m['accentFirstBeat']) ?? d.accentFirstBeat,
    subdivision: _int(m['subdivision']) ?? d.subdivision,
    volume: _num(m['volume']) ?? d.volume,
  ).validated();
}
