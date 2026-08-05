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
    expect(NovelSource.epub('/a.epub').format, NovelFormat.epub);
    expect(NovelSource.text('/a.txt').format, NovelFormat.text);
    expect(NovelSource.markdown('/a.md').format, NovelFormat.markdown);
    expect(NovelSource.html('/a.html').format, NovelFormat.html);
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

  test('searchParagraphs', () {
    final hits = searchParagraphs(
      ['hello world', 'foo bar', 'hello again'],
      query: 'hello',
    );
    expect(hits.length, 2);
  });

  test('ReaderProgress json', () {
    const p = ReaderProgress(bookId: 'b1', pageIndex: 3, percentage: 0.5);
    final again = ReaderProgress.fromJson(p.toJson());
    expect(again.bookId, 'b1');
    expect(again.pageIndex, 3);
  });

  test('trial helpers', () {
    final limit = ReaderTrialLimit.pages(3);
    expect(limit.visibleCount(10), 3);
    expect(limit.hasMoreBeyond(10), isTrue);
    expect(limit.atBoundary(2, 10), isTrue);
    expect(limit.clampIndex(9, 10), 2);
    expect(
      ReaderTrialLimit.chapters(3, startChapter: 1).maxReadableIndex(12),
      3,
    );
    expect(trialPageCount(10, 3), 3);
    expect(clampTrialPage(9, 10, 3), 2);
  });
}
