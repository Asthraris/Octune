import 'note_name.dart';

/// One detected (or recorded) note. Shared schema for live detection and persistence.
final class NoteEvent {
  const NoteEvent({
    required this.tMs,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.amp,
    required this.conf,
  });

  final int tMs;
  final NoteName noteName;
  final int octave;
  final double cents;
  final double amp;
  final double conf;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      't_ms': tMs,
      'note': noteName.jsonName,
      'octave': octave,
      'cents': _jsonNumber(cents),
      'amp': _jsonNumber(amp),
      'conf': _jsonNumber(conf),
    };
  }

  factory NoteEvent.fromJson(Map<String, Object?> json) {
    return NoteEvent(
      tMs: (json['t_ms']! as num).toInt(),
      noteName: NoteName.parse(json['note']! as String),
      octave: (json['octave']! as num).toInt(),
      cents: (json['cents']! as num).toDouble(),
      amp: (json['amp']! as num).toDouble(),
      conf: (json['conf']! as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteEvent &&
        other.tMs == tMs &&
        other.noteName == noteName &&
        other.octave == octave &&
        other.cents == cents &&
        other.amp == amp &&
        other.conf == conf;
  }

  @override
  int get hashCode => Object.hash(tMs, noteName, octave, cents, amp, conf);
}

Object _jsonNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round();
  }
  return value;
}
