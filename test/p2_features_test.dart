import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';
import 'package:phantasm_read/src/common/reader_swipe_physics.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUp(ReaderKv.useMemoryForTesting);

  test('swipeSensitivity is validated, copied and persisted', () async {
    expect(const ReaderSettings().swipeSensitivity, 1.0);
    final s = const ReaderSettings().copyWith(swipeSensitivity: 1.5);
    expect(s.swipeSensitivity, 1.5);
    expect(s == const ReaderSettings(), isFalse);
    expect(() => ReaderSettings(swipeSensitivity: 3), throwsAssertionError);
    await ReaderSettingsStore.instance.save(s);
    expect((await ReaderSettingsStore.instance.load())!.swipeSensitivity, 1.5);
  });

  test('swipe physics scale drag and fling threshold', () {
    expect(readerSwipePhysics(1.0), isNull);
    final fast = readerSwipePhysics(2.0)! as ReaderSwipePhysics;
    final slow = readerSwipePhysics(0.5)! as ReaderSwipePhysics;
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      pixels: 0,
      viewportDimension: 400,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );
    expect(fast.applyPhysicsToUserOffset(metrics, 10), 20);
    expect(slow.applyPhysicsToUserOffset(metrics, 10), 5);
    expect(
      fast.toleranceFor(metrics).velocity,
      lessThan(slow.toleranceFor(metrics).velocity),
    );
  });

  test('highlight color and note can be updated', () async {
    final store = ReaderBookmarkStore.instance;
    await store.addHighlight(
      const ReaderHighlight(
        id: 'h',
        bookId: 'b',
        excerpt: 'x',
        paragraphIndex: 1,
      ),
    );
    await store.updateHighlightColor('b', 'h', 0xFF64B5F6);
    await store.updateHighlightNote('b', 'h', 'remember');
    final h = (await store.listHighlights('b')).single;
    expect(h.color, 0xFF64B5F6);
    expect(h.note, 'remember');
  });

  testWidgets('webtoon view honours page gap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 600,
          child: ComicWebtoonView(
            count: 2,
            gap: 40,
            cacheExtent: 0,
            itemBuilder: (i) => SizedBox(key: ValueKey(i), height: 100),
            onIndexChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final a = tester.getTopLeft(find.byKey(const ValueKey(0))).dy;
    final b = tester.getTopLeft(find.byKey(const ValueKey(1))).dy;
    expect(b - a, 140);
  });

  testWidgets('text highlight sheet saves the chosen color and note', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Chapter 1\nhello world\n\n${List.filled(5, 'body').join('\n')}',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NovelReader(
          bookId: 'hl-book',
          source: NovelSource.textBytes(bytes),
          persistSettings: false,
          persistProgress: false,
          strings: ReaderStrings.en,
          settings: const ReaderSettings(
            immersive: false,
            keepScreenOn: false,
            novelReadingMode: NovelReadingMode.vertical,
          ),
        ),
      ),
    );
    for (
      var i = 0;
      i < 20 &&
          find.byType(TextField).evaluate().isEmpty &&
          find.text('Chapter 1').evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    await tester.tapAt(const Offset(100, 300));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.highlight).first);
    await settle(tester);
    // Copy + note + five color chips are offered.
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
    final chips = find.bySemanticsLabel('Highlight');
    expect(chips, findsNWidgets(5));
    await tester.tap(chips.at(2));
    await settle(tester);
    final stored = await tester.runAsync(
      () => ReaderBookmarkStore.instance.listHighlights('hl-book'),
    );
    expect(stored, hasLength(1));
    expect(stored!.single.color, 0xFF64B5F6);
    await tester.pumpWidget(const SizedBox());
  });
}
