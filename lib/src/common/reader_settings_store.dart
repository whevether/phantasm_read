import 'dart:convert';

import 'package:synchronized/synchronized.dart';

import 'novel_reading_mode.dart';
import 'novel_typography.dart';
import 'reader_kv.dart';
import 'reader_settings.dart';

/// Persist global reader preferences.
class ReaderSettingsStore {
  ReaderSettingsStore._();
  static final ReaderSettingsStore instance = ReaderSettingsStore._();

  static const _key = 'phantasm_reader_settings';

  final _lock = Lock();
  ReaderSettings? _queued;
  Future<void>? _draining;

  /// Persists [settings]. Rapid successive calls (slider drags) are coalesced:
  /// while a write is in flight only the most recent value is kept and
  /// written next. The returned future completes once [settings] (or a newer
  /// value) has been stored.
  Future<void> save(ReaderSettings settings) {
    _queued = settings;
    return _draining ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_queued != null) {
        final next = _queued!;
        _queued = null;
        await _lock.synchronized(
          () => ReaderKv.setString(_key, jsonEncode(_toJson(next))),
        );
      }
    } finally {
      _draining = null;
    }
  }

  Future<ReaderSettings?> load() async {
    await _draining;
    final raw = await ReaderKv.getString(_key);
    if (raw == null) return null;
    try {
      return _fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _toJson(ReaderSettings s) => {
    'brightness': s.brightness,
    'keepScreenOn': s.keepScreenOn,
    'fontSize': s.typography.fontSize,
    'lineHeight': s.typography.lineHeight,
    'fontFamily': s.typography.fontFamily,
    'letterSpacing': s.typography.letterSpacing,
    'textAlign': s.typography.textAlign.name,
    'pageMargin': s.typography.pageMargin,
    'backgroundColor': s.backgroundColor,
    'foregroundColor': s.foregroundColor,
    'novelReadingMode': s.novelReadingMode.name,
    'comicFitMode': s.comicFitMode.name,
    'doublePage': s.doublePage,
    'comicBackground': s.comicBackground,
    'tapZonesEnabled': s.tapZonesEnabled,
    'immersive': s.immersive,
    'volumeKeyPaging': s.volumeKeyPaging,
    'comicAutoCrop': s.comicAutoCrop,
  };

  ReaderSettings _fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      brightness: _number(json['brightness'], 0.8, 0, 1),
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      typography: NovelTypography(
        fontSize: _number(json['fontSize'], 18, 1, 200),
        lineHeight: _number(json['lineHeight'], 1.6, 0.1, 10),
        fontFamily: json['fontFamily'] as String?,
        letterSpacing: _number(json['letterSpacing'], 0, -10, 100),
        textAlign: TextAlignOption.values.firstWhere(
          (e) => e.name == json['textAlign'],
          orElse: () => TextAlignOption.left,
        ),
        pageMargin: _number(json['pageMargin'], 20, 0, 1000),
      ),
      backgroundColor: json['backgroundColor'] as int?,
      foregroundColor: json['foregroundColor'] as int?,
      novelReadingMode: NovelReadingMode.values.firstWhere(
        (e) => e.name == json['novelReadingMode'],
        orElse: () => NovelReadingMode.horizontal,
      ),
      comicFitMode: ComicFitMode.values.firstWhere(
        (e) => e.name == json['comicFitMode'],
        orElse: () => ComicFitMode.contain,
      ),
      doublePage: json['doublePage'] as bool? ?? false,
      comicBackground: json['comicBackground'] as int? ?? 0xFF000000,
      tapZonesEnabled: json['tapZonesEnabled'] as bool? ?? true,
      immersive: json['immersive'] as bool? ?? true,
      volumeKeyPaging: json['volumeKeyPaging'] as bool? ?? false,
      comicAutoCrop: json['comicAutoCrop'] as bool? ?? false,
    );
  }
}

double _number(Object? input, double fallback, double min, double max) {
  if (input is! num || !input.isFinite) return fallback;
  return input.toDouble().clamp(min, max);
}
