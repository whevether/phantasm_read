import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/page_reader_toolbar.dart';

List<String> _all(ReaderStrings s) => [
  s.bookmarks,
  s.imageLoadFailed,
  s.noReadableContent,
  s.loadFailed,
  s.nextChapter,
  s.previousChapter,
  s.progress,
  s.emptyDocument,
  s.noContent,
  s.selectChapter,
  s.noToc,
  s.searchFailed,
  s.toggleToolbar,
  s.orientation,
  s.fit,
  s.doublePage,
  s.doublePageOff,
  s.doublePageSwitchHint,
  s.bookmark,
  s.bookmarkList,
  s.thumbnails,
  s.keepScreenOn,
  s.volumeKeyPaging,
  s.volumeKeyPagingOff,
  s.fullscreen,
  s.exitFullscreen,
  s.goToPageTitle,
  s.goToPage,
  s.cancel,
  s.confirm,
  s.autoScroll,
  s.tts,
  s.audioPlay,
  s.audioPause,
  s.undoInk,
  s.clearInk,
  s.autoCrop,
  s.autoCropOff,
  s.searchHint,
  s.lineHeight,
  s.pageMargin,
  s.letterSpacing,
  s.alignJustify,
  s.alignLeft,
  s.systemFont,
  s.searchOutsideTrial,
  s.noResults,
  s.pageOfFormat,
  s.pageNFormat,
  s.paragraphNFormat,
  s.retry,
  s.delete,
  s.previousPage,
  s.nextPage,
  s.search,
  s.toc,
  s.highlight,
  s.addBookmark,
  s.removeBookmark,
  s.fitContain,
  s.fitWidth,
  s.fitHeight,
  s.readingMode,
  s.modeHorizontal,
  s.modeVertical,
  s.modeWebtoon,
  s.epubUnsupported,
  s.pdfEncrypted,
  s.brightness,
  s.fontSize,
];

Widget _toolbar(ReaderStrings strings) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        PageReaderToolbar(
          strings: strings,
          showAutoCrop: true,
          currentPage: 1,
          totalPages: 10,
          progress: 0.1,
          settings: const ReaderSettings(),
          mode: ComicReadingMode.horizontal,
          bookmarked: false,
          onModeChanged: (_) {},
          onSettingsChanged: (_) {},
          onToggleBookmark: () {},
          onShowBookmarks: () {},
          onShowThumbs: () {},
          onSeek: (_) {},
          onPageInput: (_) {},
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('PageReaderToolbar uses injected English strings', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar(ReaderStrings.en));
    expect(find.byTooltip('Reading mode: Horizontal'), findsOneWidget);
    expect(find.text('Page 1 of 10'), findsOneWidget);
    expect(find.byTooltip('Bookmark list'), findsOneWidget);
    expect(find.byTooltip('Auto-crop margins'), findsOneWidget);
    expect(find.byTooltip('方向'), findsNothing);
    expect(find.text('Go to'), findsOneWidget);
  });

  testWidgets('PageReaderToolbar renders Thai strings', (tester) async {
    await tester.pumpWidget(_toolbar(ReaderStrings.th));
    expect(find.byTooltip('โหมดการอ่าน: แนวนอน'), findsOneWidget);
    expect(find.text('ไปที่'), findsOneWidget);
  });

  test('Southeast Asian presets are complete and localised', () {
    final zh = _all(ReaderStrings.zh);
    for (final code in ['th', 'vi', 'id', 'ms', 'fil']) {
      final s = ReaderStrings.presets[code]!;
      final values = _all(s);
      expect(values.every((v) => v.trim().isNotEmpty), isTrue, reason: code);
      // No Chinese text may leak into another language preset.
      expect(
        values.any((v) => RegExp(r'[\u4e00-\u9fff]').hasMatch(v)),
        isFalse,
        reason: code,
      );
      // Translated, not copied from the Chinese default.
      expect(values.first, isNot(zh.first), reason: code);
    }
  });

  test('forLanguageCode / forLocale resolve codes, aliases and fallback', () {
    expect(ReaderStrings.forLanguageCode('th'), same(ReaderStrings.th));
    expect(ReaderStrings.forLanguageCode('vi-VN'), same(ReaderStrings.vi));
    expect(ReaderStrings.forLanguageCode('id_ID'), same(ReaderStrings.id));
    expect(ReaderStrings.forLanguageCode('in'), same(ReaderStrings.id));
    expect(ReaderStrings.forLanguageCode('ms-MY'), same(ReaderStrings.ms));
    expect(ReaderStrings.forLanguageCode('fil'), same(ReaderStrings.fil));
    expect(ReaderStrings.forLanguageCode('tl'), same(ReaderStrings.fil));
    expect(ReaderStrings.forLanguageCode('zh-CN'), same(ReaderStrings.zh));
    expect(ReaderStrings.forLanguageCode('fr'), same(ReaderStrings.en));
    expect(ReaderStrings.forLanguageCode(null), same(ReaderStrings.en));
    expect(
      ReaderStrings.forLocale(const Locale('th', 'TH')),
      same(ReaderStrings.th),
    );
    expect(
      ReaderStrings.forLanguageCode('xx', fallback: ReaderStrings.zh),
      same(ReaderStrings.zh),
    );
  });

  test('Traditional Chinese resolves by script and region', () {
    expect(ReaderStrings.forLanguageCode('zh-TW'), same(ReaderStrings.zhHant));
    expect(
      ReaderStrings.forLanguageCode('zh_Hant_HK'),
      same(ReaderStrings.zhHant),
    );
    expect(
      ReaderStrings.forLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      same(ReaderStrings.zhHant),
    );
    expect(
      ReaderStrings.forLocale(const Locale('zh', 'HK')),
      same(ReaderStrings.zhHant),
    );
    expect(
      ReaderStrings.forLocale(const Locale('zh', 'CN')),
      same(ReaderStrings.zh),
    );
    expect(ReaderStrings.zhHant.bookmarks, '書籤');
    expect(_all(ReaderStrings.zhHant).every((v) => v.isNotEmpty), isTrue);
  });

  test('templates fill in numbers', () {
    expect(ReaderStrings.en.pageOf(3, 10), 'Page 3 of 10');
    expect(ReaderStrings.zh.pageN(5), '第 5 页');
    expect(ReaderStrings.en.paragraphN(2), 'Paragraph 2');
    expect(
      ReaderStrings.en.outsideTrial(4),
      '4 more results are outside the preview',
    );
    for (final entry in ReaderStrings.presets.entries) {
      final s = entry.value;
      expect(s.searchOutsideTrial, contains('{n}'), reason: entry.key);
      expect(
        s.pageOfFormat,
        allOf(contains('{page}'), contains('{total}')),
        reason: entry.key,
      );
      expect(s.pageNFormat, contains('{n}'), reason: entry.key);
      expect(s.paragraphNFormat, contains('{n}'), reason: entry.key);
    }
  });
}
