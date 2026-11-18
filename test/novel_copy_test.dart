import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';

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

  testWidgets('selection sheet copy action closes the sheet', (tester) async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Chapter 1\nhello world\n\n${List.filled(5, 'body').join('\n')}',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NovelReader(
          bookId: 'copy-book',
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
    await tester.tap(find.text('Copy'));
    await settle(tester);
    // The selection sheet closes after copying.
    expect(find.text('Copy'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
