/// Text alignment for novels.
enum TextAlignOption { left, justify }

/// Comic image fit modes.
enum ComicFitMode { contain, width, height }

const _unchangedFamily = Object();

/// Novel typography controls (text + EPUB only).
class NovelTypography {
  const NovelTypography({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.fontFamily,
    this.letterSpacing = 0,
    this.textAlign = TextAlignOption.left,
    this.pageMargin = 20,
  }) : assert(fontSize > 0),
       assert(lineHeight > 0),
       assert(pageMargin >= 0);

  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
  final double letterSpacing;
  final TextAlignOption textAlign;
  final double pageMargin;

  NovelTypography copyWith({
    double? fontSize,
    double? lineHeight,
    Object? fontFamily = _unchangedFamily,
    double? letterSpacing,
    TextAlignOption? textAlign,
    double? pageMargin,
  }) {
    return NovelTypography(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: identical(fontFamily, _unchangedFamily)
          ? this.fontFamily
          : fontFamily as String?,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textAlign: textAlign ?? this.textAlign,
      pageMargin: pageMargin ?? this.pageMargin,
    );
  }
}
