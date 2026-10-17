import 'dart:typed_data';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:extended_image/extended_image.dart';
import 'package:phantasm_read/src/novel/text/text_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/novel/text/text_decoder.dart';
import 'package:phantasm_read/src/novel/text/text_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Markdown formatting preserves body text', () {
    expect(
      const NovelTextDecoder().normalizeContent('**hello**', kind: 'markdown'),
      'hello',
    );
  });
  test('System font selection clears previous font', () {
    expect(
      const NovelTypography(fontFamily: 'serif')
          .copyWith(fontFamily: null)
          .fontFamily,
      isNull,
    );
  });
  test('HTML preserves block boundaries', () {
    expect(
      const NovelTextDecoder().normalizeContent(
        '<p>one</p><p>two</p>',
        kind: 'html',
      ),
      'one\n\ntwo',
    );
  });
  test('Long paragraphs split without losing text or overflowing', () {
    final paragraph = List.filled(300, 'long text').join(' ');
    const style = TextStyle(fontSize: 18, height: 1.6);
    final pages = paginateParagraphs(
      paragraphs: [paragraph],
      pageSize: const Size(200, 200),
      style: style,
      padding: const EdgeInsets.all(20),
    );
    expect(pages.length, greaterThan(1));
    expect(pages.expand((p) => p).join(), paragraph);
    for (final page in pages) {
      final tp = TextPainter(
        text: TextSpan(text: page.single, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      expect(tp.height, lessThanOrEqualTo(160.01));
      tp.dispose();
    }
  });
  test('CBZ pages use natural sorting', () {
    final zip = Archive();
    for (final n in [1, 2, 10]) {
      zip.addFile(ArchiveFile('$n.png', 1, [n]));
    }
    final pages = ComicArchive.fromBytes(
      Uint8List.fromList(ZipEncoder().encode(zip)),
    ) as ComicPagesBytes;
    expect(pages.bytes.map((b) => b.first).toList(), [1, 2, 10]);
  });
  test('Concurrent bookmark writes preserve both additions', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait([
      ReaderBookmarkStore.instance.addBookmark(
        const ReaderBookmark(id: '1', bookId: 'audit', title: 'one'),
      ),
      ReaderBookmarkStore.instance.addBookmark(
        const ReaderBookmark(id: '2', bookId: 'audit', title: 'two'),
      ),
    ]);
    final items = await ReaderBookmarkStore.instance.listBookmarks('audit');
    expect(items.length, 2);
  });
  test('Empty trial window clamps safely', () {
    expect(ReaderTrialLimit.pages(2, startPage: 20).clampIndex(100, 10), 9);
  });
  testWidgets('Double-page comic never displays image beyond trial', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
    );
    final images = List.generate(4, (_) => Uint8List.fromList(png));
    await tester.pumpWidget(
      MaterialApp(
        // extended_image still uses the legacy Material widget tree.
        // ignore: deprecated_member_use
        builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
        home: ComicReader(
          pages: ComicPages.fromBytes(images),
          initialPage: 2,
          readingMode: ComicReadingMode.horizontal,
          settings: const ReaderSettings(
            doublePage: true,
            immersive: false,
            keepScreenOn: false,
          ),
          persistProgress: false,
          persistSettings: false,
          trialLimit: ReaderTrialLimit.pages(3),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final providers = tester
        .widgetList<ExtendedImage>(find.byType(ExtendedImage))
        .map((w) => w.image)
        .whereType<MemoryImage>();
    expect(providers.any((p) => identical(p.bytes, images[3])), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('Vertical paragraph navigation scrolls to unbuilt content', (
    tester,
  ) async {
    final key = GlobalKey<TextReaderState>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 400,
          child: TextReader(
            key: key,
            bytes: Uint8List.fromList(
              utf8.encode(
                List.generate(
                  200,
                  (i) => 'paragraph $i with body text',
                ).join('\n\n'),
              ),
            ),
            kind: 'text',
            typography: const NovelTypography(),
            readingMode: NovelReadingMode.vertical,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    final jump = key.currentState!.jumpToParagraph(150);
    await tester.pumpAndSettle();
    await jump;
    expect(key.currentState!.currentParagraph, 150);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(before),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
