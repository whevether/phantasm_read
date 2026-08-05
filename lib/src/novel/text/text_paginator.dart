import 'package:flutter/painting.dart';

/// Paginate [paragraphs] into pages that roughly fit [pageSize].
List<List<String>> paginateParagraphs({
  required List<String> paragraphs,
  required Size pageSize,
  required TextStyle style,
  required EdgeInsets padding,
}) {
  if (paragraphs.isEmpty) return const [];
  final maxWidth = (pageSize.width - padding.horizontal).clamp(1.0, double.infinity);
  final maxHeight = (pageSize.height - padding.vertical).clamp(1.0, double.infinity);

  final pages = <List<String>>[];
  var current = <String>[];
  var usedHeight = 0.0;
  final gap = (style.fontSize ?? 16) * 0.8;

  for (final paragraph in paragraphs) {
    final tp = TextPainter(
      text: TextSpan(text: paragraph, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: maxWidth);
    final h = tp.height;

    if (current.isNotEmpty && usedHeight + gap + h > maxHeight) {
      pages.add(current);
      current = <String>[];
      usedHeight = 0;
    }
    if (current.isNotEmpty) usedHeight += gap;
    current.add(paragraph);
    usedHeight += h;

    // Oversized single paragraph: still keep alone on a page.
    if (current.length == 1 && h > maxHeight) {
      pages.add(current);
      current = <String>[];
      usedHeight = 0;
    }
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}
