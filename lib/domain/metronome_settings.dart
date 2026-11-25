/// Metronome configuration. Immutable; call [validated] to clamp.
class MetronomeSettings {
  const MetronomeSettings({
    this.bpm = 100,
    this.beatsPerBar = 4,
    this.beatUnit = 4,
    this.accentFirstBeat = true,
    this.subdivision = 1,
    this.volume = 0.8,
  });

  static const int minBpm = 20;
  static const int maxBpm = 240;
  static const int minBeatsPerBar = 1;
  static const int maxBeatsPerBar = 12;
  static const int maxSubdivision = 4;
  static const List<int> beatUnits = [2, 4, 8, 16];

  /// Beats per minute, counted in [beatUnit] notes.
  final int bpm;
  final int beatsPerBar;

  /// Denominator of the time signature. Display only: [bpm] already counts
  /// beats of this unit, so it does not change timing.
  final int beatUnit;
  final bool accentFirstBeat;

  /// Clicks per beat (1 = none extra). Extra clicks are quieter.
  final int subdivision;

  /// 0..1 playback volume.
  final double volume;

  double get beatIntervalMs => 60000 / bpm;

  MetronomeSettings validated() => MetronomeSettings(
        bpm: bpm.clamp(minBpm, maxBpm),
        beatsPerBar: beatsPerBar.clamp(minBeatsPerBar, maxBeatsPerBar),
        beatUnit: beatUnits.contains(beatUnit) ? beatUnit : 4,
        accentFirstBeat: accentFirstBeat,
        subdivision: subdivision.clamp(1, maxSubdivision),
        volume: volume.clamp(0.0, 1.0).toDouble(),
      );

  /// True when [other] would need a different rendered click pattern.
  /// (Volume alone can be changed without re-rendering.)
  bool sameClickPatternAs(MetronomeSettings other) =>
      bpm == other.bpm &&
      beatsPerBar == other.beatsPerBar &&
      accentFirstBeat == other.accentFirstBeat &&
      subdivision == other.subdivision;

  MetronomeSettings copyWith({
    int? bpm,
    int? beatsPerBar,
    int? beatUnit,
    bool? accentFirstBeat,
    int? subdivision,
    double? volume,
  }) =>
      MetronomeSettings(
        bpm: bpm ?? this.bpm,
        beatsPerBar: beatsPerBar ?? this.beatsPerBar,
        beatUnit: beatUnit ?? this.beatUnit,
        accentFirstBeat: accentFirstBeat ?? this.accentFirstBeat,
        subdivision: subdivision ?? this.subdivision,
        volume: volume ?? this.volume,
      );

  @override
  bool operator ==(Object other) =>
      other is MetronomeSettings &&
      other.bpm == bpm &&
      other.beatsPerBar == beatsPerBar &&
      other.beatUnit == beatUnit &&
      other.accentFirstBeat == accentFirstBeat &&
      other.subdivision == subdivision &&
      other.volume == volume;

  @override
  int get hashCode =>
      Object.hash(bpm, beatsPerBar, beatUnit, accentFirstBeat, subdivision, volume);

  @override
  String toString() =>
      'MetronomeSettings($bpm bpm, $beatsPerBar/$beatUnit, accent=$accentFirstBeat, '
      'sub=$subdivision, vol=$volume)';
}
