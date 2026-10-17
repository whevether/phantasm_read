import 'dart:async';

import 'package:flutter/widgets.dart';

import 'reader_brightness.dart';
import 'reader_settings.dart';
import 'reader_wake_lock.dart';
import 'tap_zones.dart';

/// Serializes global display effects and restores the previously active reader.
class ReaderSession with WidgetsBindingObserver {
  ReaderSession(this.brightness);
  final ReaderBrightness brightness;
  ReaderSettings _settings = const ReaderSettings();
  bool _closed = false;
  bool _active = false;
  static final _readers = <ReaderSession>[];
  static Future<void> _effects = Future.value();
  static bool _foreground = true;

  Future<void> apply(ReaderSettings settings) {
    if (_closed) return Future.value();
    _settings = settings;
    if (!_active) {
      _active = true;
      final state = WidgetsBinding.instance.lifecycleState;
      _foreground = state == null || state == AppLifecycleState.resumed;
      _readers.add(this);
      WidgetsBinding.instance.addObserver(this);
    }
    return _schedule();
  }

  static Future<void> _schedule() {
    final next = _effects.then((_) async {
      final top = _readers.lastOrNull;
      if (top == null || !_foreground) {
        await ReaderWakeLock.disable();
        if (top == null) await ReaderImmersive.leave();
        return;
      }
      await top.brightness.apply(top._settings.brightness);
      if (top._closed || _readers.lastOrNull != top) return;
      if (top._settings.keepScreenOn) {
        await ReaderWakeLock.enable();
      } else {
        await ReaderWakeLock.disable();
      }
      if (top._settings.immersive) {
        await ReaderImmersive.enter();
      } else {
        await ReaderImmersive.leave();
      }
    });
    _effects = next.catchError((Object _) {});
    return _effects;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_schedule());
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _readers.remove(this);
    WidgetsBinding.instance.removeObserver(this);
    final cleanup = _effects.then((_) => brightness.restore());
    _effects = cleanup.catchError((Object _) {});
    unawaited(_schedule().whenComplete(brightness.dispose));
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
