import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_wiring.dart';
import 'ui/debug_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildProductionOverrides(
    useDemoInput: const bool.fromEnvironment('OCTUNE_DEMO'),
  );
  runApp(ProviderScope(overrides: overrides, child: const OctuneApp()));
}

class OctuneApp extends StatelessWidget {
  const OctuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octune',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DebugHome(),
    );
  }
}
