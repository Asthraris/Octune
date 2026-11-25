import 'package:wakelock_plus/wakelock_plus.dart';

import '../wakelock_service.dart';

class WakelockPlusService implements WakelockService {
  @override
  Future<void> setEnabled(bool value) =>
      value ? WakelockPlus.enable() : WakelockPlus.disable();
}
