import 'wake_lock_service.dart';

WakeLockService createWakeLock() => _StubWakeLock();

class _StubWakeLock implements WakeLockService {
  @override
  bool get isSupported => false;

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}
