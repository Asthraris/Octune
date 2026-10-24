import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octune/domain/spectrum_view.dart';

void main() {
  test('empty spectrum', () {
    final SpectrumView empty = SpectrumView.empty();
    expect(empty.magnitudesDb, isEmpty);
    expect(empty.minHz, 0);
    expect(empty.maxHz, 0);
    expect(empty.peakHz, isNull);
    expect(empty.peakDb, 0);
    expect(SpectrumView.empty(), empty);
  });

  test('copies magnitudes and compares by value', () {
    final Float32List bins = Float32List.fromList(<double>[-12, -6, 0]);
    final SpectrumView view = SpectrumView(
      magnitudesDb: bins,
      minHz: 65,
      maxHz: 2100,
      peakHz: 440,
      peakDb: -3,
    );
    bins[0] = 99;
    expect(view.magnitudesDb[0], -12);

    expect(
      view,
      SpectrumView(
        magnitudesDb: Float32List.fromList(<double>[-12, -6, 0]),
        minHz: 65,
        maxHz: 2100,
        peakHz: 440,
        peakDb: -3,
      ),
    );
  });
}
