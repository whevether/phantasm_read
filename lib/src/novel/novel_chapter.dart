/// A chapter entry for novel navigation (EPUB TOC or detected text headings).
class NovelChapter {
  const NovelChapter({
    required this.title,
    required this.href,
    this.children = const [],
    this.anchorIndex,
  });

  /// Display title.
  final String title;

  /// EPUB href / CFI target, or empty for text chapters.
  final String href;

  /// Nested TOC entries.
  final List<NovelChapter> children;

  /// For text novels: paragraph index to jump to.
  final int? anchorIndex;

  List<NovelChapter> get flattened {
    final out = <NovelChapter>[this];
    for (final child in children) {
      out.addAll(child.flattened);
    }
    return out;
  }

  factory NovelChapter.fromJson(Map<String, dynamic> json) {
    final kids = (json['children'] as List?)
            ?.whereType<Map>()
            .map((e) => NovelChapter.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <NovelChapter>[];
    return NovelChapter(
      title: (json['label'] ?? json['title'] ?? '').toString(),
      href: (json['href'] ?? '').toString(),
      children: kids,
    );
  }
}
