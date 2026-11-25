import 'note_name.dart';

/// Presentation preferences.
class UiSettings {
  const UiSettings({
    this.accidentalPreference = AccidentalPreference.sharps,
    this.showCents = true,
    this.keepScreenAwake = true,
    this.reduceMotion = false,
  });

  final AccidentalPreference accidentalPreference;
  final bool showCents;
  final bool keepScreenAwake;
  final bool reduceMotion;

  UiSettings copyWith({
    AccidentalPreference? accidentalPreference,
    bool? showCents,
    bool? keepScreenAwake,
    bool? reduceMotion,
  }) =>
      UiSettings(
        accidentalPreference: accidentalPreference ?? this.accidentalPreference,
        showCents: showCents ?? this.showCents,
        keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  @override
  bool operator ==(Object other) =>
      other is UiSettings &&
      other.accidentalPreference == accidentalPreference &&
      other.showCents == showCents &&
      other.keepScreenAwake == keepScreenAwake &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode =>
      Object.hash(accidentalPreference, showCents, keepScreenAwake, reduceMotion);
}
