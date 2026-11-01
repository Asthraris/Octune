import 'note_name.dart';

/// One detected note at one moment. The single schema shared by live
/// detection and (later) persistence:
/// `{"t_ms":1840,"note":"A","octave":4,"cents":-7,"amp":0.42,"conf":0.93}`
class NoteEvent {
  const NoteEvent({
    required this.tMs,
    required this.noteName,
    required this.octave,
    required this.cents,
    required this.amp,
    required this.conf,
  });

  factory NoteEvent.fromJson(Map<String, dynamic> json) => NoteEvent(
        tMs: (json['t_ms'] as num).toInt(),
        noteName: noteNameFromAscii(json['note'] as String),
        octave: (json['octave'] as num).toInt(),
        cents: (json['cents'] as num).toDouble(),
        amp: (json['amp'] as num).toDouble(),
        conf: (json['conf'] as num).toDouble(),
      );

  final int tMs;
  final NoteName noteName;
  final int octave;
  final double cents;
  final double amp;
  final double conf;

  int get midiNumber => (octave + 1) * 12 + noteName.pitchClass;

  static double _round(double v, int digits) =>
      double.parse(v.toStringAsFixed(digits));

  Map<String, dynamic> toJson() => {
        't_ms': tMs,
        'note': noteName.asciiName,
        'octave': octave,
        'cents': _round(cents, 1),
        'amp': _round(amp, 3),
        'conf': _round(conf, 3),
      };

  @override
  bool operator ==(Object other) =>
      other is NoteEvent &&
      other.tMs == tMs &&
      other.noteName == noteName &&
      other.octave == octave &&
      other.cents == cents &&
      other.amp == amp &&
      other.conf == conf;

  @override
  int get hashCode => Object.hash(tMs, noteName, octave, cents, amp, conf);

  @override
  String toString() => 'NoteEvent(${toJson()})';
}
