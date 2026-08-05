import 'dart:typed_data';

import 'novel_bytes_source.dart';

enum NovelFormat { epub, text, markdown, html }

/// Book source for [NovelReader].
sealed class NovelSource {
  const NovelSource();

  NovelFormat get format;
  NovelBytesSource get bytes;

  /// Local file path helpers (backward compatible).
  factory NovelSource.epub(String path) =>
      NovelSourceData(NovelFormat.epub, NovelBytesSource.file(path));
  factory NovelSource.text(String path) =>
      NovelSourceData(NovelFormat.text, NovelBytesSource.file(path));
  factory NovelSource.markdown(String path) =>
      NovelSourceData(NovelFormat.markdown, NovelBytesSource.file(path));
  factory NovelSource.html(String path) =>
      NovelSourceData(NovelFormat.html, NovelBytesSource.file(path));

  factory NovelSource.epubAsset(String assetPath) =>
      NovelSourceData(NovelFormat.epub, NovelBytesSource.asset(assetPath));
  factory NovelSource.epubUrl(String url, {Map<String, String>? headers}) =>
      NovelSourceData(NovelFormat.epub, NovelBytesSource.url(url, headers: headers));
  factory NovelSource.epubBytes(Uint8List bytes, {String name = 'book.epub'}) =>
      NovelSourceData(NovelFormat.epub, NovelBytesSource.bytes(bytes, name: name));

  factory NovelSource.textAsset(String assetPath) =>
      NovelSourceData(NovelFormat.text, NovelBytesSource.asset(assetPath));
  factory NovelSource.textUrl(String url, {Map<String, String>? headers}) =>
      NovelSourceData(NovelFormat.text, NovelBytesSource.url(url, headers: headers));
  factory NovelSource.textBytes(Uint8List bytes, {String name = 'book.txt'}) =>
      NovelSourceData(NovelFormat.text, NovelBytesSource.bytes(bytes, name: name));

  factory NovelSource.markdownAsset(String assetPath) =>
      NovelSourceData(NovelFormat.markdown, NovelBytesSource.asset(assetPath));
  factory NovelSource.htmlAsset(String assetPath) =>
      NovelSourceData(NovelFormat.html, NovelBytesSource.asset(assetPath));
}

final class NovelSourceData extends NovelSource {
  const NovelSourceData(this.format, this.bytes);

  @override
  final NovelFormat format;

  @override
  final NovelBytesSource bytes;
}

/// Backward-compatible aliases used by pattern matching in older call sites.
typedef NovelSourceEpub = NovelSourceData;
typedef NovelSourceText = NovelSourceData;
typedef NovelSourceMarkdown = NovelSourceData;
typedef NovelSourceHtml = NovelSourceData;
