import 'wake_lock_service_stub.dart'
    if (dart.library.js_interop) 'wake_lock_service_web.dart';

abstract class WakeLockService {
  static WakeLockService? _instance;
  static WakeLockService get shared => _instance ??= createWakeLock();
  bool get isSupported;
  Future<void> acquire();
  Future<void> release();
}
