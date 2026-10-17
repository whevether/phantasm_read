import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';

class FakeAudio extends Fake implements AudioPlayer {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final completions = StreamController<void>.broadcast(sync: true);
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Stream<void> get onPlayerComplete => completions.stream;
  @override
  Future<void> setSource(Source source) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await positions.close();
    await completions.close();
  }
}

void main() {
  test(
    'Repeated audio loads deliver one cue/completion and dispose subscriptions',
    () async {
      final audio = FakeAudio();
      var changes = 0, completions = 0;
      final player = MediaOverlayPlayer(
        player: audio,
        onCueChanged: (_) => changes++,
        onCompleted: () => completions++,
      );
      const cue = MediaOverlayCue(startMs: 0, endMs: 1000, paragraphIndex: 0);
      for (var i = 0; i < 3; i++) {
        await player.load(
          source: UrlSource('https://example.invalid/audio'),
          cues: [cue],
        );
      }
      changes = 0;
      audio.positions.add(const Duration(milliseconds: 100));
      expect(changes, 1);
      expect(player.activeCue, cue);
      audio.completions.add(null);
      expect(completions, 1);
      expect(player.activeCue, isNull);
      await player.dispose();
      expect(audio.positions.hasListener, isFalse);
      expect(audio.completions.hasListener, isFalse);
    },
  );
}
