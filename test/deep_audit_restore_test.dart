import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/novel/text/text_reader.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

NovelSource book() {
  final text = [
    for (var c = 1; c <= 8; c++) ...[
      '第$c章 标题$c',
      for (var p = 0; p < 4; p++) 'body $c-$p secret-needle-$c',
    ],
  ].join('\n');
  return NovelSource.textBytes(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  setUp(ReaderKv.useMemoryForTesting);

  testWidgets('saved progress beyond the trial window is clamped on restore', (
    tester,
  ) async {
    await ReaderProgressStore.instance.save(
      const ReaderProgress(bookId: 'trial-restore', paragraphIndex: 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NovelReader(
          bookId: 'trial-restore',
          source: book(),
          persistSettings: false,
          trialLimit: ReaderTrialLimit.chapters(2),
          settings: const ReaderSettings(
            immersive: false,
            keepScreenOn: false,
            novelReadingMode: NovelReadingMode.vertical,
          ),
        ),
      ),
    );
    await settle(tester);
    final state = tester.state<TextReaderState>(find.byType(TextReader));
    // Two chapters of five paragraphs each: indices 0..9 are readable.
    expect(state.currentParagraph, lessThanOrEqualTo(9));
    await tester.pumpWidget(const SizedBox());
    // Let the asynchronous teardown (session release) finish inside the test.
    await settle(tester);
  });
}
