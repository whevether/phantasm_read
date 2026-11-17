import 'dart:typed_data';

/// Normalized crop rectangle (fractions of width/height, 0..1).
class ComicCropRect {
  const ComicCropRect(this.left, this.top, this.right, this.bottom);

  static const ComicCropRect full = ComicCropRect(0, 0, 1, 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get isFull => left <= 0 && top <= 0 && right >= 1 && bottom >= 1;

  @override
  String toString() => 'ComicCropRect($left, $top, $right, $bottom)';
}

/// Detects near-uniform margins (white or black) in an RGBA image.
class ComicAutoCrop {
  const ComicAutoCrop._();

  /// [rgba] is width*height*4 bytes. A row/column counts as blank when all its
  /// pixels are within [tolerance] of the corner background luminance.
  /// Crop per side is limited to [maxCrop] of each dimension so a mostly blank
  /// page is never reduced to nothing.
  static ComicCropRect detect(
    Uint8List rgba,
    int width,
    int height, {
    int tolerance = 16,
    double maxCrop = 0.2,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return ComicCropRect.full;
    }
    final bg = _lum(rgba, 0);
    bool blankRow(int y) {
      for (var x = 0; x < width; x++) {
        if ((_lum(rgba, (y * width + x) * 4) - bg).abs() > tolerance) {
          return false;
        }
      }
      return true;
    }

    bool blankCol(int x) {
      for (var y = 0; y < height; y++) {
        if ((_lum(rgba, (y * width + x) * 4) - bg).abs() > tolerance) {
          return false;
        }
      }
      return true;
    }

    final maxY = (height * maxCrop).floor();
    final maxX = (width * maxCrop).floor();
    var top = 0;
    while (top < maxY && blankRow(top)) {
      top++;
    }
    var bottom = 0;
    while (bottom < maxY && blankRow(height - 1 - bottom)) {
      bottom++;
    }
    var left = 0;
    while (left < maxX && blankCol(left)) {
      left++;
    }
    var right = 0;
    while (right < maxX && blankCol(width - 1 - right)) {
      right++;
    }
    // A fully uniform page (no content anywhere) must not be trimmed.
    if (top == maxY &&
        bottom == maxY &&
        left == maxX &&
        right == maxX &&
        blankRow(height ~/ 2) &&
        blankCol(width ~/ 2)) {
      return ComicCropRect.full;
    }
    return ComicCropRect(
      left / width,
      top / height,
      1 - right / width,
      1 - bottom / height,
    );
  }

  static int _lum(Uint8List d, int i) =>
      (d[i] * 299 + d[i + 1] * 587 + d[i + 2] * 114) ~/ 1000;
}
