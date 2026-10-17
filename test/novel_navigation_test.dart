import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/novel/text/text_reader.dart';

Widget host(Widget reader) => MaterialApp(home: reader);
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Reflow preserves position inside a long paragraph and separates fragment anchors',
    (tester) async {
      final key = GlobalKey<TextReaderState>();
      final bytes = Uint8List.fromList(
        utf8.encode(List.filled(700, '中文 👩🏽‍🚀 paragraph ').join()),
      );
      Widget reader(double font) => host(
        TextReader(
          key: key,
          bytes: bytes,
          kind: 'text',
          initialParagraph: 0,
          initialTextOffset: 3000,
          typography: NovelTypography(fontSize: font),
        ),
      );
      await tester.pumpWidget(reader(18));
      await settle(tester);
      var view = tester.widget<CurlPageView>(find.byType(CurlPageView));
      expect(view.controller!.initialPage, greaterThan(0));
      final offset = key.currentState!.currentTextOffset;
      expect(offset, 3000);
      await tester.pumpWidget(reader(22));
      await settle(tester);
      view = tester.widget<CurlPageView>(find.byType(CurlPageView));
      expect(view.controller!.initialPage, greaterThan(0));
      expect(key.currentState!.characterProgress, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Rapid source swaps show the latest text and settings updates preserve state',
    (tester) async {
      final old = NovelSource.textBytes(
        Uint8List.fromList(utf8.encode('Chapter 1\nold content')),
      );
      final bytes = Uint8List.fromList(
        utf8.encode(
          'Chapter 9\nnew content\n\n${List.filled(20, 'more body').join('\n')}',
        ),
      );
      Widget reader(NovelSource source, double brightness) => host(
        NovelReader(
          source: source,
          persistSettings: false,
          persistProgress: false,
          settings: ReaderSettings(
            brightness: brightness,
            immersive: false,
            keepScreenOn: false,
            novelReadingMode: NovelReadingMode.vertical,
          ),
        ),
      );
      await tester.pumpWidget(reader(old, 0.8));
      await tester.pumpWidget(reader(NovelSource.textBytes(bytes), 0.8));
      await settle(tester);
      final state = tester.state<TextReaderState>(find.byType(TextReader));
      expect(state.paragraphs, contains('new content'));
      expect(state.paragraphs, isNot(contains('old content')));
      await tester.pumpWidget(
        reader(NovelSource.textBytes(Uint8List.fromList(bytes)), 0.6),
      );
      await settle(tester);
      expect(
        identical(
          tester.state<TextReaderState>(find.byType(TextReader)),
          state,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Disposing while asset bytes are pending does not create a late session timer',
    (tester) async {
      final response = Completer<ByteData?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (_) => response.future);
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      await tester.pumpWidget(
        host(
          NovelReader(
            source: NovelSource.textAsset('pending.txt'),
            persistSettings: false,
            persistProgress: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      response.complete(
        ByteData.sublistView(Uint8List.fromList(utf8.encode('late content'))),
      );
      await settle(tester);
      await tester.pump(const Duration(seconds: 31));
      expect(tester.takeException(), isNull);
    },
  );
}
