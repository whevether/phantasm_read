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
    this.volumeKeyPaging = false,
    this.comicAutoCrop = false,
    this.swipeSensitivity = 1.0,
  }) : assert(brightness >= 0 && brightness <= 1),
       assert(swipeSensitivity >= 0.5 && swipeSensitivity <= 2.0);

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
  @Deprecated('Tap gestures toggle the toolbar; this setting is ignored.')
  final bool tapZonesEnabled;
  final bool immersive;

  /// Use hardware volume keys to turn pages. Off by default.
  final bool volumeKeyPaging;

  /// Trim near-uniform margins from comic pages (off by default).
  final bool comicAutoCrop;

  /// Page-swipe sensitivity, 0.5 (needs a longer drag) to 2.0 (flips on a
  /// short drag). 1.0 is the framework default.
  final double swipeSensitivity;

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
    bool? volumeKeyPaging,
    bool? comicAutoCrop,
    double? swipeSensitivity,
    bool clearBackgroundColor = false,
    bool clearForegroundColor = false,
  }) {
    return ReaderSettings(
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      typography: typography ?? this.typography,
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      foregroundColor: clearForegroundColor
          ? null
          : (foregroundColor ?? this.foregroundColor),
      novelReadingMode: novelReadingMode ?? this.novelReadingMode,
      comicFitMode: comicFitMode ?? this.comicFitMode,
      doublePage: doublePage ?? this.doublePage,
      comicBackground: comicBackground ?? this.comicBackground,
      tapZonesEnabled: tapZonesEnabled ?? this.tapZonesEnabled,
      immersive: immersive ?? this.immersive,
      volumeKeyPaging: volumeKeyPaging ?? this.volumeKeyPaging,
      comicAutoCrop: comicAutoCrop ?? this.comicAutoCrop,
      swipeSensitivity: swipeSensitivity ?? this.swipeSensitivity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderSettings &&
          other.brightness == brightness &&
          other.keepScreenOn == keepScreenOn &&
          other.typography == typography &&
          other.backgroundColor == backgroundColor &&
          other.foregroundColor == foregroundColor &&
          other.novelReadingMode == novelReadingMode &&
          other.comicFitMode == comicFitMode &&
          other.doublePage == doublePage &&
          other.comicBackground == comicBackground &&
          // ignore: deprecated_member_use_from_same_package
          other.tapZonesEnabled == tapZonesEnabled &&
          other.immersive == immersive &&
          other.volumeKeyPaging == volumeKeyPaging &&
          other.comicAutoCrop == comicAutoCrop &&
          other.swipeSensitivity == swipeSensitivity;

  @override
  int get hashCode => Object.hash(
    brightness,
    keepScreenOn,
    typography,
    backgroundColor,
    foregroundColor,
    novelReadingMode,
    comicFitMode,
    doublePage,
    comicBackground,
    // ignore: deprecated_member_use_from_same_package
    tapZonesEnabled,
    immersive,
    volumeKeyPaging,
    comicAutoCrop,
    swipeSensitivity,
  );
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
    NovelThemePreset(
      name: 'Cream',
      background: 0xFFFFF8E7,
      foreground: 0xFF222222,
    ),
    NovelThemePreset(
      name: 'White',
      background: 0xFFFFFFFF,
      foreground: 0xFF111111,
    ),
    NovelThemePreset(
      name: 'Sepia',
      background: 0xFFF4ECD8,
      foreground: 0xFF5B4636,
    ),
    NovelThemePreset(
      name: 'Green',
      background: 0xFFCCE8CF,
      foreground: 0xFF1B3A22,
    ),
    NovelThemePreset(
      name: 'Dark',
      background: 0xFF121212,
      foreground: 0xFFE0E0E0,
    ),
    NovelThemePreset(
      name: 'AMOLED',
      background: 0xFF000000,
      foreground: 0xFFE8E8E8,
    ),
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
