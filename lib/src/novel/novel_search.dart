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

/// Simple in-text search over paragraph list.
List<NovelSearchHit> searchParagraphs(
  List<String> paragraphs, {
  required String query,
  List<NovelChapter>? chapters,
}) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final lower = q.toLowerCase();
  final hits = <NovelSearchHit>[];
  for (var i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    final idx = p.toLowerCase().indexOf(lower);
    if (idx < 0) continue;
    final start = (idx - 20).clamp(0, p.length);
    final end = (idx + q.length + 40).clamp(0, p.length);
    String? chapterTitle;
    if (chapters != null) {
      for (final c in chapters) {
        final a = c.anchorIndex;
        if (a != null && a <= i) chapterTitle = c.title;
      }
    }
    hits.add(
      NovelSearchHit(
        excerpt: p.substring(start, end),
        paragraphIndex: i,
        chapterTitle: chapterTitle,
      ),
    );
  }
  return hits;
}
