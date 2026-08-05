import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';

void main() {
  test('ReaderSettings copyWith', () {
    const settings = ReaderSettings(brightness: 0.5);
    final next = settings.copyWith(brightness: 0.9, keepScreenOn: false);
    expect(next.brightness, 0.9);
    expect(next.keepScreenOn, isFalse);
    expect(next.typography.fontSize, 18);
  });

  test('ComicPages length', () {
    final pages = ComicPages.fromUrls(['a', 'b', 'c']);
    expect(pages.length, 3);
  });

  test('NovelSource factories', () {
    expect(NovelSource.epub('/a.epub'), isA<NovelSourceEpub>());
    expect(NovelSource.text('/a.txt'), isA<NovelSourceText>());
    expect(NovelSource.markdown('/a.md'), isA<NovelSourceMarkdown>());
    expect(NovelSource.html('/a.html'), isA<NovelSourceHtml>());
  });
  test('NovelChapter fromJson', () {
    final chapter = NovelChapter.fromJson({
      'label': '第一章',
      'href': 'chap1.xhtml',
      'children': [
        {'label': '1.1', 'href': 'chap1.xhtml#a'},
      ],
    });
    expect(chapter.title, '第一章');
    expect(chapter.flattened.length, 2);
  });

  test('NovelThemePreset defaults', () {
    expect(NovelThemePreset.defaults, isNotEmpty);
  });
}
