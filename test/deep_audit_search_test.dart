import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
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

  testWidgets('search never reveals text outside the trial window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NovelReader(
          bookId: 'trial-search',
          source: book(),
          persistSettings: false,
          persistProgress: false,
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
    for (
      var i = 0;
      i < 60 && find.byType(SelectableText).evaluate().isEmpty;
      i++
    ) {
      await settle(tester);
    }
    // Toggle the toolbar by tapping the reading area, then open search.
    await tester.tapAt(const Offset(4, 300));
    await settle(tester);
    final search = find.byIcon(Icons.search);
    expect(search, findsWidgets);
    await tester.tap(search.first);
    await settle(tester);
    await tester.enterText(find.byType(EditableText).last, 'secret-needle');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.textContaining('secret-needle-1'), findsWidgets);
    expect(find.textContaining('secret-needle-5'), findsNothing);
    await tester.drag(find.byType(ListTile).first, const Offset(0, -2000));
    await settle(tester);
    expect(find.text(ReaderStrings.en.outsideTrial(24)), findsOneWidget);
    expect(find.textContaining('secret-needle-5'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    // Let the asynchronous teardown (session release) finish inside the test.
    await settle(tester);
  });
}
