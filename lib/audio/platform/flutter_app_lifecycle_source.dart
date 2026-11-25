import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app_lifecycle_source.dart';

/// Foreground/background from Flutter's lifecycle.
///
/// Only `paused` counts as background. `inactive` is transient on phones
/// (notification shade, permission dialog) and also fires whenever a desktop
/// window loses focus, which must not stop the microphone.
class FlutterAppLifecycleSource with WidgetsBindingObserver implements AppLifecycleSource {
  FlutterAppLifecycleSource() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get foreground => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.add(state != AppLifecycleState.paused);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}
