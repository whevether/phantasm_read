import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'novel_reading_mode.dart';
import 'novel_typography.dart';
import 'reader_settings.dart';

/// Persist global reader preferences.
class ReaderSettingsStore {
  ReaderSettingsStore._();
  static final ReaderSettingsStore instance = ReaderSettingsStore._();

  static const _key = 'phantasm_reader_settings';

  Future<void> save(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson(settings)));
  }

  Future<ReaderSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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
      };

  ReaderSettings _fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.8,
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      typography: NovelTypography(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
        fontFamily: json['fontFamily'] as String?,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
        textAlign: TextAlignOption.values.firstWhere(
          (e) => e.name == json['textAlign'],
          orElse: () => TextAlignOption.left,
        ),
        pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 20,
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
    );
  }
}
