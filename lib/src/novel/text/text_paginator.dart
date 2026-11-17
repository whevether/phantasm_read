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
  final pages = <List<TextFragment>>[];
  for (final _ in _paginateSteps(
    paragraphs: paragraphs,
    pageSize: pageSize,
    style: style,
    padding: padding,
    textScaler: textScaler,
    textDirection: textDirection,
    textAlign: textAlign,
    startIndex: startIndex,
    out: pages,
  )) {}
  return pages;
}

/// Same result as [paginateText], but yields to the event loop about every
/// [budget] so a long book does not freeze the UI. [isCancelled] is polled
/// between slices; a cancelled run returns `null`.
Future<List<List<TextFragment>>?> paginateTextAsync({
  required List<String> paragraphs,
  required Size pageSize,
  required TextStyle style,
  required EdgeInsets padding,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
  TextAlign textAlign = TextAlign.left,
  int startIndex = 0,
  bool Function()? isCancelled,
  Duration budget = const Duration(milliseconds: 8),
}) async {
  final pages = <List<TextFragment>>[];
  final clock = Stopwatch()..start();
  for (final _ in _paginateSteps(
    paragraphs: paragraphs,
    pageSize: pageSize,
    style: style,
    padding: padding,
    textScaler: textScaler,
    textDirection: textDirection,
    textAlign: textAlign,
    startIndex: startIndex,
    out: pages,
  )) {
    if (clock.elapsed >= budget) {
      await Future<void>.delayed(Duration.zero);
      if (isCancelled?.call() ?? false) return null;
      clock.reset();
    }
  }
  return (isCancelled?.call() ?? false) ? null : pages;
}

Iterable<void> _paginateSteps({
  required List<String> paragraphs,
  required Size pageSize,
  required TextStyle style,
  required EdgeInsets padding,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
  TextAlign textAlign = TextAlign.left,
  int startIndex = 0,
  required List<List<TextFragment>> out,
}) sync* {
  final width = (pageSize.width - padding.horizontal).clamp(
    1.0,
    double.infinity,
  );
  final height = (pageSize.height - padding.vertical).clamp(
    1.0,
    double.infinity,
  );
  final gap = (style.fontSize ?? 16) * 0.8;
  final pages = out;
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
      var take = low == 0 ? 1 : low;
      if (low > 0 && cursor + low < graphemes.length) {
        // The paragraph continues on the next page: end this page on a
        // complete line so words (and Thai/Khmer/Myanmar clusters laid out by
        // the engine) are never cut in the middle.
        take = _lineAlignedTake(
          graphemes: graphemes,
          cursor: cursor,
          fit: low,
          available: available,
          style: style,
          width: width,
          textDirection: textDirection,
          textAlign: textAlign,
          textScaler: textScaler,
        );
      }
      // A viewport shorter than one line remains scrollable in the renderer.
      final text = graphemes.sublist(cursor, cursor + take).join();
      page.add(TextFragment(text, startIndex + i, startOffset: textOffset));
      textOffset += text.length;
      used += spacing + measure(text);
      cursor += take;
      if (cursor < graphemes.length) flush();
    }
    yield null;
  }
  flush();
}

/// Number of graphemes from [cursor] that end exactly on a line boundary and
/// still fit into [available] pixels. Falls back to [fit] when no complete
/// line can be determined.
int _lineAlignedTake({
  required List<String> graphemes,
  required int cursor,
  required int fit,
  required double available,
  required TextStyle style,
  required double width,
  required TextDirection textDirection,
  required TextAlign textAlign,
  required TextScaler textScaler,
}) {
  final lookEnd = (cursor + fit + 200).clamp(0, graphemes.length);
  final text = graphemes.sublist(cursor, lookEnd).join();
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textAlign: textAlign,
    textScaler: textScaler,
  );
  try {
    painter.layout(maxWidth: width);
    final lines = painter.computeLineMetrics();
    var bottom = 0.0;
    var lastFullTop = -1.0;
    var lastFullHeight = 0.0;
    for (final line in lines) {
      if (bottom + line.height > available + 0.01) break;
      lastFullTop = bottom;
      lastFullHeight = line.height;
      bottom += line.height;
    }
    if (lastFullTop < 0) return fit;
    final probe = painter.getPositionForOffset(
      Offset(width / 2, lastFullTop + lastFullHeight / 2),
    );
    final end = painter.getLineBoundary(probe).end;
    if (end <= 0 || end > text.length) return fit;
    // UTF-16 offset -> grapheme count.
    var units = 0;
    var count = 0;
    while (count < lookEnd - cursor && units < end) {
      units += graphemes[cursor + count].length;
      count++;
    }
    return count <= 0 ? fit : count;
  } finally {
    painter.dispose();
  }
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
