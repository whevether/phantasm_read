import 'package:wakelock_plus/wakelock_plus.dart';

/// Keep-screen-on helper. Always pair [enable] with [disable].
class ReaderWakeLock {
  const ReaderWakeLock._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Web / unsupported platforms: ignore.
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
