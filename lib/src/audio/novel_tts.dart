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

/// Optional capability for [NovelTtsEngine] implementations that can change
/// the spoken language (e.g. `flutter_tts.setLanguage`). [NovelReader] calls
/// it with a BCP-47 tag (`NovelReader.ttsLanguage`, or the EPUB's
/// `dc:language`) before speaking. Implement it next to [NovelTtsEngine].
abstract interface class NovelTtsLanguageAware {
  Future<void> setLanguage(String languageTag);
}

/// Splits [text] into chunks of at most [maxLength] characters, preferring
/// paragraph and sentence ends, so engines with a per-utterance length limit
/// (Android's is about 4000) can read a whole chapter.
List<String> chunkForTts(String text, {int maxLength = 3000}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.length <= maxLength) return [trimmed];
  final chunks = <String>[];
  var rest = trimmed;
  final breaks = RegExp(r'[\n\u3002\uFF01\uFF1F.!?\u2026;\uFF1B]');
  while (rest.length > maxLength) {
    var cut = -1;
    for (final m in breaks.allMatches(rest.substring(0, maxLength))) {
      cut = m.end;
    }
    if (cut <= maxLength ~/ 3) {
      // No sentence end in the window: fall back to the last space.
      final space = rest.lastIndexOf(' ', maxLength);
      cut = space > maxLength ~/ 3 ? space + 1 : maxLength;
    }
    chunks.add(rest.substring(0, cut).trim());
    rest = rest.substring(cut).trimLeft();
  }
  if (rest.isNotEmpty) chunks.add(rest);
  return chunks.where((c) => c.isNotEmpty).toList();
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
