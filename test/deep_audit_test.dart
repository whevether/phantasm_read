import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_identity.dart';
import 'package:phantasm_read/src/novel/text/text_decoder.dart';
import 'package:phantasm_read/src/novel/text/text_paginator.dart';
import 'package:phantasm_read/src/novel/text/text_reader.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ReaderKv.useMemoryForTesting);

  group('ReaderTrialLimit value semantics', () {
    test('equal limits compare equal and hash alike', () {
      final a = ReaderTrialLimit.chapters(3, startChapter: 1);
      final b = ReaderTrialLimit.chapters(3, startChapter: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(ReaderTrialLimit.pages(3, startPage: 1)));
      expect(a, isNot(ReaderTrialLimit.chapters(4, startChapter: 1)));
    });
  });

  group('novel search', () {
    final paragraphs = ['alpha needle', 'beta', 'needle again', 'needle end'];

    test('hits outside the trial window are hidden and counted', () {
      final result = searchParagraphsInWindow(
        paragraphs,
        query: 'needle',
        minIndex: 0,
        maxIndex: 0,
      );
      expect(result.hits.map((h) => h.paragraphIndex), [0]);
      expect(result.hiddenCount, 2);
      for (final hit in result.hits) {
        expect(hit.excerpt, isNot(contains('again')));
      }
    });

    test('NFC and NFD forms match each other', () {
      final composed = 'caf\u00e9 au lait';
      final decomposed = 'cafe\u0301 au lait';
      expect(searchParagraphs([composed], query: decomposed), hasLength(1));
      expect(searchParagraphs([decomposed], query: composed), hasLength(1));
    });

    test('diacritic-insensitive retry finds unaccented queries', () {
      expect(searchParagraphs(['Việt Nam'], query: 'viet'), isEmpty);
      expect(
        searchParagraphs(['Việt Nam'], query: 'viet', ignoreDiacritics: true),
        hasLength(1),
      );
    });
  });

  group('text pagination', () {
    const style = TextStyle(fontSize: 16, height: 1.4);
    final paragraph = List.generate(400, (i) => 'word${i % 17}').join(' ');

    test('long paragraphs split on whole lines, never inside a word', () {
      final pages = paginateText(
        paragraphs: [paragraph],
        pageSize: const Size(220, 160),
        style: style,
        padding: const EdgeInsets.all(8),
      );
      expect(pages.length, greaterThan(2));
      final fragments = [for (final page in pages) ...page];
      expect(fragments.map((f) => f.text).join(), paragraph);
      for (var i = 0; i < fragments.length - 1; i++) {
        final left = fragments[i].text;
        final right = fragments[i + 1].text;
        final boundaryIsSpace =
            left.endsWith(' ') || right.startsWith(' ') || left.endsWith('\n');
        expect(
          boundaryIsSpace,
          isTrue,
          reason:
              'fragment $i ends mid-word: …${left.substring(left.length - 6)}',
        );
      }
    });

    test('async pagination matches the synchronous result', () async {
      final sync = paginateText(
        paragraphs: [paragraph, paragraph],
        pageSize: const Size(220, 160),
        style: style,
        padding: const EdgeInsets.all(8),
      );
      final async = await paginateTextAsync(
        paragraphs: [paragraph, paragraph],
        pageSize: const Size(220, 160),
        style: style,
        padding: const EdgeInsets.all(8),
        budget: Duration.zero,
      );
      expect(async, isNotNull);
      expect(async!.length, sync.length);
      for (var i = 0; i < sync.length; i++) {
        expect(
          async[i].map((f) => f.text).toList(),
          sync[i].map((f) => f.text).toList(),
        );
      }
    });

    test('async pagination can be cancelled', () async {
      var cancelled = false;
      final future = paginateTextAsync(
        paragraphs: List.filled(50, paragraph),
        pageSize: const Size(220, 160),
        style: style,
        padding: const EdgeInsets.all(8),
        budget: Duration.zero,
        isCancelled: () => cancelled,
      );
      cancelled = true;
      expect(await future, isNull);
    });
  });

  group('text decoding', () {
    test('scores prefer a real decoding over mojibake', () {
      final best = NovelTextDecoder.chooseBestDecoding({
        'gb18030': '这是一段正常的中文文本。',
        'windows-1252': 'Ö÷Á÷ÐÂÎÅ¡£',
        'big5': '\uFFFD\uFFFD\uFFFD\uFFFD',
      });
      expect(best, 'gb18030');
    });

    test('HTML meta charset is sniffed', () {
      final html = Uint8List.fromList(
        '<html><head><meta charset="gbk"></head>'.codeUnits,
      );
      expect(NovelTextDecoder.sniffHtmlCharset(html), 'gbk');
      final legacy = Uint8List.fromList(
        '<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS">'
            .codeUnits,
      );
      expect(NovelTextDecoder.sniffHtmlCharset(legacy), 'Shift_JIS');
    });

    test('HTML entities decode (named and numeric)', () {
      expect(
        NovelTextDecoder.decodeHtmlEntities(
          'a&amp;b &lt;c&gt; &#x4e2d;&#25991;',
        ),
        'a&b <c> 中文',
      );
    });

    test('UTF-16 BOM and encoding aliases', () async {
      final decoder = NovelTextDecoder();
      final bytes = Uint8List.fromList([
        0xFF, 0xFE, // BOM (LE)
        0x48, 0x00, 0x69, 0x00,
      ]);
      expect(await decoder.decodeBytes(bytes), 'Hi');
      expect(NovelTextDecoder.canonicalEncoding('GB2312'), 'gbk');
      expect(NovelTextDecoder.canonicalEncoding('UTF_8'), 'utf-8');
      expect(NovelTextDecoder.canonicalEncoding('Shift_JIS'), 'shift_jis');
    });
  });

  group('multilingual chapter detection', () {
    List<String> titles(List<String> paragraphs) => detectTextChapters(
      paragraphs,
      headings: const [],
    ).map((c) => c.title).toList();

    test('recognises headings in several languages', () {
      final result = titles([
        '第一章 开始',
        '正文',
        'Chapter 2: The Road',
        'text',
        'Bab 3 Perjalanan',
        'text',
        'Chương 4 Khởi đầu',
        'text',
        'บทที่ 5 เริ่มต้น',
        'text',
        'Kabanata 6',
        'text',
      ]);
      expect(result, hasLength(6));
    });

    test('ordinary sentences are not chapters', () {
      expect(
        titles([
          'He read chapter two of the book last night and slept.',
          'The part about love was long.',
        ]),
        isEmpty,
      );
    });
  });

  group('stats tracker', () {
    test('ignores fly-by positions below minDwell', () async {
      final tracker = ReaderStatsTracker(
        'b',
        minDwell: const Duration(milliseconds: 40),
      );
      tracker.visit(0, chars: 10);
      tracker.visit(1, chars: 10); // left immediately: not counted
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final stats = tracker.snapshot();
      expect(stats.pagesRead, 1);
      expect(stats.charsRead, 10);
    });

    test('pause stops the clock', () async {
      final tracker = ReaderStatsTracker('b');
      tracker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final first = tracker.snapshot().duration;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(tracker.snapshot().duration, first);
      tracker.resume();
    });
  });

  group('tts chunking', () {
    test('short text stays whole, long text splits on sentences', () {
      expect(chunkForTts('Hello.'), ['Hello.']);
      final sentence = 'This is a sentence. ';
      final long = sentence * 400;
      final chunks = chunkForTts(long, maxLength: 1000);
      expect(chunks.length, greaterThan(1));
      expect(chunks.every((c) => c.length <= 1000), isTrue);
      expect(chunks.every((c) => c.endsWith('.')), isTrue);
      expect(
        chunks.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
        long.replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    });

    test('text without separators is hard-split', () {
      final chunks = chunkForTts('x' * 2500, maxLength: 1000);
      expect(chunks.map((c) => c.length), [1000, 1000, 500]);
    });
  });

  group('services', () {
    test('sync hub serializes callbacks and swallows host errors', () async {
      final order = <String>[];
      final errors = <Object>[];
      final hub = ReaderSyncHub(
        onSync: (payload) async {
          order.add('start ${payload.bookId}');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (payload.bookId == 'bad') throw StateError('boom');
          order.add('end ${payload.bookId}');
        },
        onError: (e, _) => errors.add(e),
      );
      await Future.wait([
        hub.emit(const ReaderSyncPayload(bookId: 'a')),
        hub.emit(const ReaderSyncPayload(bookId: 'bad')),
        hub.emit(const ReaderSyncPayload(bookId: 'c')),
      ]);
      expect(order, ['start a', 'end a', 'start bad', 'start c', 'end c']);
      expect(errors, hasLength(1));
    });

    test('settings store coalesces bursts and keeps the last value', () async {
      final store = ReaderSettingsStore.instance;
      final writes = <Future<void>>[
        for (var i = 1; i <= 20; i++)
          store.save(ReaderSettings(brightness: i / 20)),
      ];
      await Future.wait(writes);
      final loaded = await store.load();
      expect(loaded!.brightness, closeTo(1.0, 1e-9));
    });

    test('bookmark saves and adds do not deadlock or lose data', () async {
      final store = ReaderBookmarkStore.instance;
      await Future.wait([
        store.addBookmark(
          const ReaderBookmark(
            id: 'a',
            bookId: 'deep',
            title: '',
            pageIndex: 1,
          ),
        ),
        store.saveBookmarks('deep-2', const []),
        store.addBookmark(
          const ReaderBookmark(
            id: 'b',
            bookId: 'deep',
            title: '',
            pageIndex: 2,
          ),
        ),
      ]);
      final list = await store.listBookmarks('deep');
      expect(list.map((b) => b.pageIndex).toSet(), {1, 2});
    });

    test('byte identity is stable and memoised per buffer', () {
      final bytes = Uint8List.fromList(List.generate(1024, (i) => i % 251));
      final a = readerBytesIdentity('x', bytes);
      expect(readerBytesIdentity('x', bytes), a);
      expect(readerBytesIdentity('y', bytes), isNot(a));
      expect(
        readerBytesIdentity('x', Uint8List.fromList(bytes)),
        a,
        reason: 'equal content hashes alike',
      );
    });
  });
}
