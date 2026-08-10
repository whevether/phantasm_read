import 'novel_reading_mode.dart';
import 'novel_typography.dart';

/// Shared reader settings for comic and novel.
class ReaderSettings {
  const ReaderSettings({
    this.brightness = 0.8,
    this.keepScreenOn = true,
    this.typography = const NovelTypography(),
    this.backgroundColor,
    this.foregroundColor,
    this.novelReadingMode = NovelReadingMode.horizontal,
    this.comicFitMode = ComicFitMode.contain,
    this.doublePage = false,
    this.comicBackground = 0xFF000000,
    this.tapZonesEnabled = true,
    this.immersive = true,
  });

  final double brightness;
  final bool keepScreenOn;
  final NovelTypography typography;
  final int? backgroundColor;
  final int? foregroundColor;
  final NovelReadingMode novelReadingMode;
  final ComicFitMode comicFitMode;
  final bool doublePage;
  final int comicBackground;
  /// Legacy: comic / novel / PDF taps always toggle the toolbar only
  /// (no tap-to-page). Kept for settings persistence compatibility.
  final bool tapZonesEnabled;
  final bool immersive;

  ReaderSettings copyWith({
    double? brightness,
    bool? keepScreenOn,
    NovelTypography? typography,
    int? backgroundColor,
    int? foregroundColor,
    NovelReadingMode? novelReadingMode,
    ComicFitMode? comicFitMode,
    bool? doublePage,
    int? comicBackground,
    bool? tapZonesEnabled,
    bool? immersive,
    bool clearBackgroundColor = false,
    bool clearForegroundColor = false,
  }) {
    return ReaderSettings(
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      typography: typography ?? this.typography,
      backgroundColor:
          clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      foregroundColor:
          clearForegroundColor ? null : (foregroundColor ?? this.foregroundColor),
      novelReadingMode: novelReadingMode ?? this.novelReadingMode,
      comicFitMode: comicFitMode ?? this.comicFitMode,
      doublePage: doublePage ?? this.doublePage,
      comicBackground: comicBackground ?? this.comicBackground,
      tapZonesEnabled: tapZonesEnabled ?? this.tapZonesEnabled,
      immersive: immersive ?? this.immersive,
    );
  }
}

/// Preset reading themes for novels.
class NovelThemePreset {
  const NovelThemePreset({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final int background;
  final int foreground;

  static const List<NovelThemePreset> defaults = [
    NovelThemePreset(name: 'Cream', background: 0xFFFFF8E7, foreground: 0xFF222222),
    NovelThemePreset(name: 'White', background: 0xFFFFFFFF, foreground: 0xFF111111),
    NovelThemePreset(name: 'Sepia', background: 0xFFF4ECD8, foreground: 0xFF5B4636),
    NovelThemePreset(name: 'Green', background: 0xFFCCE8CF, foreground: 0xFF1B3A22),
    NovelThemePreset(name: 'Dark', background: 0xFF121212, foreground: 0xFFE0E0E0),
    NovelThemePreset(name: 'AMOLED', background: 0xFF000000, foreground: 0xFFE8E8E8),
  ];
}

/// Built-in font family choices for novel toolbar.
class NovelFontOption {
  const NovelFontOption(this.label, this.family);
  final String label;
  final String? family;

  static const List<NovelFontOption> defaults = [
    NovelFontOption('系统', null),
    NovelFontOption('Serif', 'serif'),
    NovelFontOption('Sans', 'sans-serif'),
    NovelFontOption('Mono', 'monospace'),
  ];
}
