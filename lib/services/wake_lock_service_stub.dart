import 'package:wakelock_plus/wakelock_plus.dart';

import 'wake_lock_service.dart';

WakeLockService createWakeLock() => _NativeWakeLock();

class _NativeWakeLock implements WakeLockService {
  @override
  bool get isSupported => true;

  @override
  Future<void> acquire() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
