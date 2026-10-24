import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octune/ui/octune_app.dart';

void main() {
  testWidgets('blank dark shell renders', (tester) async {
    await tester.pumpWidget(const OctuneApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
