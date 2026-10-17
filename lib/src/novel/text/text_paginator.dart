import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

class TextFragment {
  const TextFragment(this.text, this.paragraphIndex, {this.startOffset = 0});
  final String text;
  final int paragraphIndex;
  final int startOffset;
  int get endOffset => startOffset + text.length;
}

/// A fragment retains its original paragraph anchor when a long paragraph splits.
List<List<TextFragment>> paginateText({
  required List<String> paragraphs,
  required Size pageSize,
  required TextStyle style,
  required EdgeInsets padding,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
  TextAlign textAlign = TextAlign.left,
  int startIndex = 0,
}) {
  final width = (pageSize.width - padding.horizontal).clamp(
    1.0,
    double.infinity,
  );
  final height = (pageSize.height - padding.vertical).clamp(
    1.0,
    double.infinity,
  );
  final gap = (style.fontSize ?? 16) * 0.8;
  final pages = <List<TextFragment>>[];
  var page = <TextFragment>[];
  var used = 0.0;
  double measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: textAlign,
      textScaler: textScaler,
    );
    try {
      painter.layout(maxWidth: width);
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  void flush() {
    if (page.isNotEmpty) pages.add(page);
    page = [];
    used = 0;
  }

  for (var i = 0; i < paragraphs.length; i++) {
    final graphemes = paragraphs[i].characters.toList();
    var cursor = 0;
    var textOffset = 0;
    while (cursor < graphemes.length) {
      final spacing = page.isEmpty ? 0.0 : gap;
      final available = height - used - spacing;
      var low = 0;
      var high = graphemes.length - cursor;
      while (low < high) {
        final mid = (low + high + 1) ~/ 2;
        if (measure(graphemes.sublist(cursor, cursor + mid).join()) <=
            available + 0.01) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      if (low == 0 && page.isNotEmpty) {
        flush();
        continue;
      }
      // A viewport shorter than one line remains scrollable in the renderer.
      final take = low == 0 ? 1 : low;
      final text = graphemes.sublist(cursor, cursor + take).join();
      page.add(TextFragment(text, startIndex + i, startOffset: textOffset));
      textOffset += text.length;
      used += spacing + measure(text);
      cursor += take;
      if (cursor < graphemes.length) flush();
    }
  }
  flush();
  return pages;
}

/// Compatibility wrapper for callers that do not need paragraph anchors.
List<List<String>> paginateParagraphs({
  required List<String> paragraphs,
  required Size pageSize,
  required TextStyle style,
  required EdgeInsets padding,
}) => paginateText(
  paragraphs: paragraphs,
  pageSize: pageSize,
  style: style,
  padding: padding,
).map((p) => p.map((f) => f.text).toList()).toList();
