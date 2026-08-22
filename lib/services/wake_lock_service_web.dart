import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'wake_lock_service.dart';

WakeLockService createWakeLock() => _WebWakeLock();

@JS('navigator.wakeLock')
external JSObject? _getWakeLockManager();

@JS()
extension type WakeLockManager._(JSObject _) implements JSObject {
  external JSPromise<JSObject> request(String name);
}

@JS()
extension type WakeLockSentinel._(JSObject _) implements JSObject {
  external void release();
}

class _WebWakeLock implements WakeLockService {
  WakeLockSentinel? _sentinel;

  @override
  bool get isSupported {
    try {
      _getWakeLockManager();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> acquire() async {
    if (!isSupported) return;
    try {
      final manager = _getWakeLockManager();
      if (manager == null) return;
      final wm = manager as WakeLockManager;
      final promise = wm.request('screen');
      final obj = await promise.toDart;
      _sentinel = obj as WakeLockSentinel;
    } catch (_) {}
  }

  @override
  Future<void> release() async {
    try {
      _sentinel?.release();
      _sentinel = null;
    } catch (_) {}
  }
}
