import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A timed cue for karaoke / media-overlay style sync.
class MediaOverlayCue {
  const MediaOverlayCue({
    required this.startMs,
    required this.endMs,
    this.text,
    this.paragraphIndex,
    this.cfi,
  });

  final int startMs;
  final int endMs;
  final String? text;
  final int? paragraphIndex;
  final String? cfi;

  factory MediaOverlayCue.fromJson(Map<String, dynamic> json) {
    return MediaOverlayCue(
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int? ?? 0,
      text: json['text'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
      cfi: json['cfi'] as String?,
    );
  }
}

/// Plays narration audio and reports the active cue for highlighting.
class MediaOverlayPlayer {
  MediaOverlayPlayer({
    this.onCueChanged,
    this.onCompleted,
  });

  final ValueChanged<MediaOverlayCue?>? onCueChanged;
  final VoidCallback? onCompleted;

  final AudioPlayer _player = AudioPlayer();
  List<MediaOverlayCue> _cues = const [];
  MediaOverlayCue? _active;

  MediaOverlayCue? get activeCue => _active;

  Future<void> load({
    required Source source,
    List<MediaOverlayCue> cues = const [],
  }) async {
    _cues = List.of(cues)..sort((a, b) => a.startMs.compareTo(b.startMs));
    await _player.setSource(source);
    _player.onPositionChanged.listen(_onPosition);
    _player.onPlayerComplete.listen((_) {
      _active = null;
      onCueChanged?.call(null);
      onCompleted?.call();
    });
  }

  void _onPosition(Duration pos) {
    final ms = pos.inMilliseconds;
    MediaOverlayCue? hit;
    for (final c in _cues) {
      if (ms >= c.startMs && ms < c.endMs) {
        hit = c;
        break;
      }
    }
    if (hit?.startMs != _active?.startMs || hit?.endMs != _active?.endMs) {
      _active = hit;
      onCueChanged?.call(hit);
    }
  }

  Future<void> play() => _player.resume();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Minimal audiobook controller (file / url).
class AudiobookController {
  AudiobookController();

  final AudioPlayer player = AudioPlayer();

  Future<void> playFile(String path) => player.play(DeviceFileSource(path));
  Future<void> playUrl(String url) => player.play(UrlSource(url));
  Future<void> pause() => player.pause();
  Future<void> stop() => player.stop();
  Future<void> dispose() => player.dispose();
}
