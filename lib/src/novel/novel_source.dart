/// Book source for [NovelReader].
sealed class NovelSource {
  const NovelSource();

  factory NovelSource.epub(String path) = NovelSourceEpub;
  factory NovelSource.text(String path) = NovelSourceText;
  factory NovelSource.markdown(String path) = NovelSourceMarkdown;
  factory NovelSource.html(String path) = NovelSourceHtml;
}

final class NovelSourceEpub extends NovelSource {
  const NovelSourceEpub(this.path);
  final String path;
}

final class NovelSourceText extends NovelSource {
  const NovelSourceText(this.path);
  final String path;
}

final class NovelSourceMarkdown extends NovelSource {
  const NovelSourceMarkdown(this.path);
  final String path;
}

final class NovelSourceHtml extends NovelSource {
  const NovelSourceHtml(this.path);
  final String path;
}
