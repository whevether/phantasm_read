import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

enum BrightnessMode { system, overlay }

/// Prefer system brightness; fall back to overlay dimming.
class ReaderBrightness extends ChangeNotifier {
  BrightnessMode mode = BrightnessMode.system;
  double value = 0.8;
  bool _didSetSystem = false;

  Future<void> apply(double brightness) async {
    final v = brightness.clamp(0.0, 1.0);
    value = v;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(v);
      mode = BrightnessMode.system;
      _didSetSystem = true;
    } catch (_) {
      mode = BrightnessMode.overlay;
    }
    notifyListeners();
  }

  Future<void> restore() async {
    if (_didSetSystem) {
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    _didSetSystem = false;
  }
}
