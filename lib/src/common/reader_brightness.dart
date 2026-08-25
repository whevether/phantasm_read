import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

enum BrightnessMode { system, overlay }

/// Prefer system brightness; fall back to overlay dimming.
///
/// Web (and other platforms without a `screen_brightness` impl) always use
/// [BrightnessMode.overlay] — calling the plugin on Web throws a JS
/// `TypeError` (`Cannot read properties of null (reading 'complete')`).
class ReaderBrightness extends ChangeNotifier {
  BrightnessMode mode = BrightnessMode.overlay;
  double value = 0.8;
  bool _didSetSystem = false;

  static bool get _supportsSystemBrightness => !kIsWeb;

  Future<void> apply(double brightness) async {
    final v = brightness.clamp(0.0, 1.0);
    value = v;

    if (!_supportsSystemBrightness) {
      mode = BrightnessMode.overlay;
      notifyListeners();
      return;
    }

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
    if (_didSetSystem && _supportsSystemBrightness) {
      try {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      } catch (_) {}
    }
    _didSetSystem = false;
  }
}
