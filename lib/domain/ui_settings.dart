import 'accidental_preference.dart';

final class UiSettings {
  const UiSettings({
    this.accidentalPreference = AccidentalPreference.sharps,
    this.showCents = true,
    this.keepScreenAwake = false,
    this.reduceMotion = false,
  });

  final AccidentalPreference accidentalPreference;
  final bool showCents;
  final bool keepScreenAwake;
  final bool reduceMotion;

  @override
  bool operator ==(Object other) {
    return other is UiSettings &&
        other.accidentalPreference == accidentalPreference &&
        other.showCents == showCents &&
        other.keepScreenAwake == keepScreenAwake &&
        other.reduceMotion == reduceMotion;
  }

  @override
  int get hashCode {
    return Object.hash(
      accidentalPreference,
      showCents,
      keepScreenAwake,
      reduceMotion,
    );
  }
}
