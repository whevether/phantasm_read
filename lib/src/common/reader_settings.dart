import 'novel_typography.dart';

/// Shared reader settings for comic and novel.
class ReaderSettings {
  const ReaderSettings({
    this.brightness = 0.8,
    this.keepScreenOn = true,
    this.typography = const NovelTypography(),
    this.backgroundColor,
    this.foregroundColor,
  });

  /// System or overlay brightness in range `0.0`–`1.0`.
  final double brightness;

  /// Whether to keep the screen awake while reading.
  final bool keepScreenOn;

  /// Typography for novel (text + EPUB). Ignored by comic.
  final NovelTypography typography;

  /// Optional novel theme background (ARGB int or ignored if null).
  final int? backgroundColor;

  /// Optional novel theme foreground.
  final int? foregroundColor;

  ReaderSettings copyWith({
    double? brightness,
    bool? keepScreenOn,
    NovelTypography? typography,
    int? backgroundColor,
    int? foregroundColor,
  }) {
    return ReaderSettings(
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      typography: typography ?? this.typography,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
    );
  }
}
