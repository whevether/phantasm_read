import 'package:flutter/widgets.dart';

import 'reader_brightness.dart';
import 'reader_settings.dart';
import 'reader_wake_lock.dart';

/// Applies brightness + wakelock for the lifetime of a reader page.
mixin ReaderLifecycleMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  ReaderBrightness get readerBrightness;
  ReaderSettings get readerSettings;

  Future<void> enterReading() async {
    await readerBrightness.apply(readerSettings.brightness);
    if (readerSettings.keepScreenOn) {
      await ReaderWakeLock.enable();
    } else {
      await ReaderWakeLock.disable();
    }
  }

  Future<void> leaveReading() async {
    await readerBrightness.restore();
    await ReaderWakeLock.disable();
  }

  void bindReaderLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    enterReading();
  }

  void unbindReaderLifecycle() {
    WidgetsBinding.instance.removeObserver(this);
    leaveReading();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
    } else if (state == AppLifecycleState.resumed &&
        readerSettings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }
}

/// Black overlay used when system brightness is unavailable.
class BrightnessOverlay extends StatelessWidget {
  const BrightnessOverlay({
    super.key,
    required this.brightness,
    required this.mode,
  });

  final double brightness;
  final BrightnessMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode != BrightnessMode.overlay) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Color.fromRGBO(0, 0, 0, (1.0 - brightness).clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}
