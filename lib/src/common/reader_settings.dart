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
    this.novelReadingMode = NovelReadingMode.vertical,
  });

  /// System or overlay brightness in range `0.0`–`1.0`.
  final double brightness;

  /// Whether to keep the screen awake while reading.
  final bool keepScreenOn;

  /// Typography for novel (text + EPUB). Ignored by comic.
  final NovelTypography typography;

  /// Optional novel theme background (ARGB int).
  final int? backgroundColor;

  /// Optional novel theme foreground (ARGB int).
  final int? foregroundColor;

  /// Novel layout: vertical scroll or horizontal paging.
  final NovelReadingMode novelReadingMode;

  ReaderSettings copyWith({
    double? brightness,
    bool? keepScreenOn,
    NovelTypography? typography,
    int? backgroundColor,
    int? foregroundColor,
    NovelReadingMode? novelReadingMode,
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
  ];
}
