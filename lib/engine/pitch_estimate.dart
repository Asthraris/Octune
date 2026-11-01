final class PitchEstimate {
  const PitchEstimate({
    required this.frequencyHz,
    required this.clarity,
  });

  final double frequencyHz;

  /// 0 = unvoiced, 1 = perfectly periodic.
  final double clarity;

  @override
  bool operator ==(Object other) {
    return other is PitchEstimate &&
        other.frequencyHz == frequencyHz &&
        other.clarity == clarity;
  }

  @override
  int get hashCode => Object.hash(frequencyHz, clarity);
}
