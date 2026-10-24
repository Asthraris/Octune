import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/accidental_preference.dart';
import 'package:octune/domain/ui_settings.dart';

void main() {
  test('defaults', () {
    const UiSettings settings = UiSettings();
    expect(settings.accidentalPreference, AccidentalPreference.sharps);
    expect(settings.showCents, isTrue);
    expect(settings.keepScreenAwake, isFalse);
    expect(settings.reduceMotion, isFalse);
  });

  test('equality', () {
    const UiSettings a = UiSettings(
      accidentalPreference: AccidentalPreference.flats,
      showCents: false,
      keepScreenAwake: true,
      reduceMotion: true,
    );
    const UiSettings b = UiSettings(
      accidentalPreference: AccidentalPreference.flats,
      showCents: false,
      keepScreenAwake: true,
      reduceMotion: true,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
