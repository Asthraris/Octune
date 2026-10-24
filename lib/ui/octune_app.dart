import 'package:flutter/material.dart';

class OctuneApp extends StatelessWidget {
  const OctuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octune',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
