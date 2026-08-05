import 'package:flutter/foundation.dart';

/// Text-to-speech hook for [NovelReader].
///
/// Provide a mobile implementation (e.g. `flutter_tts`) from the host app.
/// Desktop / macOS builds can omit this to avoid native plugin warnings.
abstract class NovelTtsEngine {
  Future<void> speak(String text);

  Future<void> stop();

  void setCompletionHandler(VoidCallback? handler);

  void dispose();
}

/// No-op engine used when TTS is unavailable.
class NovelTtsUnavailable implements NovelTtsEngine {
  @override
  void dispose() {}

  @override
  void setCompletionHandler(VoidCallback? handler) {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
