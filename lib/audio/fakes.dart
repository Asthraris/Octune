import 'dart:async';

import '../../domain/beat_event.dart';
import 'app_lifecycle_source.dart';
import 'permission_service.dart';
import 'wakelock_service.dart';

/// Scripted microphone permission.
class FakePermissionService implements PermissionService {
  FakePermissionService({
    this.current = MicPermissionStatus.granted,
    this.afterRequest,
  });

  MicPermissionStatus current;

  /// What a request() results in; defaults to granted.
  MicPermissionStatus? afterRequest;

  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<MicPermissionStatus> status() async => current;

  @override
  Future<MicPermissionStatus> request() async {
    requestCount++;
    current = afterRequest ?? MicPermissionStatus.granted;
    return current;
  }

  @override
  Future<void> openSettings() async => openSettingsCount++;
}

class FakeWakelockService implements WakelockService {
  bool enabled = false;
  final List<bool> history = [];

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    history.add(value);
  }
}

class FakeAppLifecycleSource implements AppLifecycleSource {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get foreground => _controller.stream;

  void setForeground(bool value) => _controller.add(value);
}

/// Clock you advance by hand.
class FakeClock implements MonotonicClock {
  FakeClock([this._now = 0]);

  double _now;

  @override
  double get nowMs => _now;

  void advance(double ms) => _now += ms;
}
