/// Novel typography controls (text + EPUB only).
class NovelTypography {
  const NovelTypography({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.fontFamily,
  });

  final double fontSize;
  final double lineHeight;
  final String? fontFamily;

  NovelTypography copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
  }) {
    return NovelTypography(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}
