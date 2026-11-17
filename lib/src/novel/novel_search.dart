import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'novel_chapter.dart';

class NovelSearchHit {
  const NovelSearchHit({
    required this.excerpt,
    this.cfi,
    this.paragraphIndex,
    this.chapterTitle,
  });

  final String excerpt;
  final String? cfi;
  final int? paragraphIndex;
  final String? chapterTitle;
}

/// Search hits plus the number of matches that fall outside the readable
/// (trial) window. Hidden matches are only counted, never exposed.
class NovelSearchResult {
  const NovelSearchResult({this.hits = const [], this.hiddenCount = 0});

  final List<NovelSearchHit> hits;
  final int hiddenCount;
}

String _fold(String value, bool ignoreDiacritics) {
  var text = unorm.nfc(value).toLowerCase();
  if (ignoreDiacritics) {
    text = unorm
        .nfd(text)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll('\u0111', 'd');
  }
  return text;
}

/// Cuts around a match at grapheme-cluster boundaries so combining marks and
/// emoji are never split. [index]/[length] are UTF-16 offsets into [text].
String _excerpt(String text, int index, int length) {
  final chars = text.characters;
  var utf16 = 0;
  var matchStart = 0;
  var matchEnd = chars.length;
  var g = 0;
  var startFound = false;
  for (final c in chars) {
    final next = utf16 + c.length;
    if (!startFound && next > index) {
      matchStart = g;
      startFound = true;
    }
    if (next >= index + length) {
      matchEnd = g + 1;
      break;
    }
    utf16 = next;
    g++;
  }
  final from = (matchStart - 20).clamp(0, chars.length);
  final to = (matchEnd + 40).clamp(0, chars.length);
  return chars.skip(from).take(to - from).toString();
}

/// In-text search over a paragraph list. Only paragraphs in
/// `[minIndex, maxIndex]` (inclusive, either bound optional) are returned as
/// hits; matches outside that range are only counted in
/// [NovelSearchResult.hiddenCount].
NovelSearchResult searchParagraphsInWindow(
  List<String> paragraphs, {
  required String query,
  List<NovelChapter>? chapters,
  int? minIndex,
  int? maxIndex,
  bool ignoreDiacritics = false,
}) {
  final q = unorm.nfc(query.trim());
  if (q.isEmpty) return const NovelSearchResult();
  final needle = _fold(q, ignoreDiacritics);
  if (needle.isEmpty) return const NovelSearchResult();
  final hits = <NovelSearchHit>[];
  var hidden = 0;
  for (var i = 0; i < paragraphs.length; i++) {
    final readable =
        (minIndex == null || i >= minIndex) &&
        (maxIndex == null || i <= maxIndex);
    final folded = _fold(paragraphs[i], ignoreDiacritics);
    final idx = folded.indexOf(needle);
    if (idx < 0) continue;
    if (!readable) {
      hidden++;
      continue;
    }
    // Excerpts are cut from the folded text: its offsets are the ones that
    // `idx` refers to (case folding may change the length of the original).
    final display = unorm.nfc(paragraphs[i]);
    final lowered = display.toLowerCase();
    final source = !ignoreDiacritics && lowered.length == display.length
        ? display
        : folded;
    String? chapterTitle;
    if (chapters != null) {
      for (final c in chapters) {
        final a = c.anchorIndex;
        if (a != null && a <= i) chapterTitle = c.title;
      }
    }
    hits.add(
      NovelSearchHit(
        excerpt: _excerpt(source, idx, needle.length),
        paragraphIndex: i,
        chapterTitle: chapterTitle,
      ),
    );
  }
  return NovelSearchResult(hits: hits, hiddenCount: hidden);
}

/// Simple in-text search over paragraph list.
List<NovelSearchHit> searchParagraphs(
  List<String> paragraphs, {
  required String query,
  List<NovelChapter>? chapters,
  bool ignoreDiacritics = false,
}) => searchParagraphsInWindow(
  paragraphs,
  query: query,
  chapters: chapters,
  ignoreDiacritics: ignoreDiacritics,
).hits;
