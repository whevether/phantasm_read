import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
// Printing exposes its platform seam in src for platform implementations.
import 'package:printing/src/interface.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_identity.dart';
import 'package:phantasm_read/src/common/reader_page_window.dart';
import 'package:phantasm_read/src/common/reader_lifecycle.dart';
import 'package:phantasm_read/src/novel/epub/epub_bridge.dart';
import 'package:phantasm_read/src/novel/novel_bytes_source.dart';
import 'package:phantasm_read/src/pdf/pdf_raster_cache.dart';

class FakePrinting extends PrintingPlatform {
  final requests = <(List<int>?, double)>[];
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);
  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    requests.add((pages, dpi));
    for (final index in pages ?? List.generate(6, (i) => i)) {
      yield PdfRaster(2, 2, Uint8List.fromList(List.filled(16, index)));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget host(Widget child) => MaterialApp(
  // extended_image still uses the legacy Material widget tree.
  // ignore: deprecated_member_use
  builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
  home: child,
);
Future<void> settleReader(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Stable IDs survive object reconstruction and distinguish in-memory books',
    () {
      final a = Uint8List.fromList([1, 2, 3]),
          b = Uint8List.fromList([1, 2, 4]);
      expect(
        ComicPages.fromUrls(['a', 'b']).stableId,
        ComicPages.fromUrls(['a', 'b']).stableId,
      );
      expect(
        NovelBytesSource.bytes(a).stableId,
        NovelBytesSource.bytes(Uint8List.fromList(a)).stableId,
      );
      expect(
        NovelBytesSource.bytes(a).stableId,
        isNot(NovelBytesSource.bytes(b).stableId),
      );
      expect(readerRecordId(), isNot(readerRecordId()));
    },
  );
  test(
    'Trial spreads handle odd starts, empty windows and absolute indices',
    () {
      final window = ReaderPageWindow(
        10,
        trial: ReaderTrialLimit.pages(4, startPage: 1),
        doublePage: true,
      );
      expect(window.count, 2);
      expect(window.content(0), 1);
      expect(window.content(1), 3);
      expect(window.logical(4), 1);
      expect(window.readable(5), isFalse);
      expect(ReaderPageWindow(0).count, 0);
      expect(
        ReaderPageWindow(
          10,
          trial: ReaderTrialLimit.pages(2, startPage: 20),
        ).count,
        0,
      );
      expect(
        () => ReaderTrialLimit.pages(2, startPage: -1),
        throwsAssertionError,
      );
    },
  );
  test('Bridge correlates replies out of order and reports failures', () async {
    final scripts = <String>[];
    final broker = EpubRequestBroker((script) async {
      scripts.add(script);
    });
    final first = broker.call('search', ['quote " and newline\n']);
    final second = broker.call('getToc');
    broker.receive({
      'id': 2,
      'result': ['toc'],
    });
    broker.receive({
      'id': 1,
      'result': ['hit'],
    });
    expect(await second, ['toc']);
    expect(await first, ['hit']);
    expect(scripts.first, contains(r'\n'));
    expect(scripts.first, contains(r'\"'));
    final failure = broker.call('next');
    final assertion = expectLater(failure, throwsStateError);
    broker.receive({'id': 3, 'error': 'not ready'});
    await assertion;
    broker.dispose();
  });
  test('Bridge times out, disposes pending requests, and ignores malformed messages', () async {
    final broker = EpubRequestBroker(
      (_) async {},
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(broker.call('getToc'), throwsA(isA<TimeoutException>()));
    final pending = broker.call('search');
    final assertion = expectLater(pending, throwsStateError);
    broker.dispose();
    await assertion;
    expect(EpubBridgeMessage.parse('{broken').type, 'invalid');
    expect(EpubBridgeMessage.parse('[]').type, 'invalid');
  });
  test('Concurrent highlight writes do not overwrite additions', () async {
    await Future.wait(
      List.generate(
        10,
        (i) => ReaderBookmarkStore.instance.addHighlight(
          ReaderHighlight(id: '$i', bookId: 'book', excerpt: 'text'),
        ),
      ),
    );
    expect(
      await ReaderBookmarkStore.instance.listHighlights('book'),
      hasLength(10),
    );
  });
  testWidgets(
    'PDF restores absolute page after page count and reloads new source',
    (tester) async {
      final old = PrintingPlatform.instance;
      final fake = FakePrinting();
      PrintingPlatform.instance = fake;
      addTearDown(() => PrintingPlatform.instance = old);
      await ReaderProgressStore.instance.save(
        const ReaderProgress(bookId: 'pdf', pageIndex: 4),
      );
      var page = -1;
      final first = PdfSource.bytes(Uint8List.fromList([1]));
      await tester.pumpWidget(
        host(
          PdfReader(
            source: first,
            bookId: 'pdf',
            onPageChanged: (i) => page = i,
            settings: const ReaderSettings(
              immersive: false,
              keepScreenOn: false,
            ),
          ),
        ),
      );
      await settleReader(tester);
      expect(page, 4);
      expect(fake.requests.first.$2, 8); // Only tiny rasters for counting.
      expect(
        fake.requests.where((r) => r.$2 == 120).every((r) => r.$1 != null),
        isTrue,
      );
      final second = PdfSource.bytes(Uint8List.fromList([2]));
      await tester.pumpWidget(
        host(
          PdfReader(
            source: second,
            bookId: 'new',
            initialPage: 2,
            onPageChanged: (i) => page = i,
            settings: const ReaderSettings(
              immersive: false,
              keepScreenOn: false,
            ),
          ),
        ),
      );
      await settleReader(tester);
      expect(page, 2);
      await tester.pumpWidget(const SizedBox());
      await settleReader(tester);
    },
  );
  test(
    'Raster cache evicts by byte budget and deduplicates pending work',
    () async {
      final old = PrintingPlatform.instance;
      final fake = FakePrinting();
      PrintingPlatform.instance = fake;
      addTearDown(() => PrintingPlatform.instance = old);
      final cache = PdfRasterCache(Uint8List(1), maxBytes: 16);
      await Future.wait([cache.page(0, 120), cache.page(0, 120)]);
      expect(fake.requests, hasLength(1));
      await cache.page(1, 120);
      await cache.page(0, 120);
      expect(fake.requests, hasLength(3));
      await cache.page(0, 24);
      expect(fake.requests.last.$2, 24);
      cache.dispose();
    },
  );
  testWidgets('Unsupported EPUB platforms display a clear fallback', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      host(
        EpubViewer(bytes: Uint8List(0), typography: const NovelTypography()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('EPUB is supported on Android'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Early dispose never activates a pending reader session', (
    tester,
  ) async {
    final brightness = ReaderBrightness();
    final session = ReaderSession(brightness);
    session.dispose();
    await session.apply(const ReaderSettings());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Ink is saved by book/page and reloads on revisit', (
    tester,
  ) async {
    Widget ink(String page) => host(
      Stack(
        children: [ReaderInk(bookId: 'ink', location: page, enabled: true)],
      ),
    );
    await tester.pumpWidget(ink('1'));
    await settleReader(tester);
    await tester.dragFrom(const Offset(50, 150), const Offset(100, 60));
    await settleReader(tester);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('phantasm_ink_${jsonEncode(['ink', '1'])}');
    expect(saved, isNotNull);
    expect((jsonDecode(saved!) as List).single['normalized'], true);
    await tester.pumpWidget(ink('2'));
    await settleReader(tester);
    expect(
      tester
          .state<InkAnnotationLayerState>(find.byType(InkAnnotationLayer))
          .strokes,
      isEmpty,
    );
    await tester.pumpWidget(ink('1'));
    await settleReader(tester);
    expect(
      tester
          .state<InkAnnotationLayerState>(find.byType(InkAnnotationLayer))
          .strokes,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
