import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keep-screen-on helper. Always pair [enable] with [disable].
class ReaderWakeLock {
  const ReaderWakeLock._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      // Web / unsupported platforms: non-fatal.
      debugPrint('ReaderWakeLock.enable failed: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('ReaderWakeLock.disable failed: $e');
    }
  }
}
