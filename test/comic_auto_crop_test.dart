import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';

Future<ui.Image> _resolve(ImageProvider p) {
  final c = Completer<ui.Image>();
  late ImageStreamListener l;
  final stream = p.resolve(ImageConfiguration.empty);
  l = ImageStreamListener((info, _) {
    c.complete(info.image);
    stream.removeListener(l);
  }, onError: (e, s) => c.completeError(e, s));
  stream.addListener(l);
  return c.future;
}

Future<MemoryImage> _png({required bool margins}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 100, 100),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.drawRect(
    margins
        ? const ui.Rect.fromLTWH(10, 10, 80, 80)
        : const ui.Rect.fromLTWH(0, 0, 100, 100),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final image = await recorder.endRecording().toImage(100, 100);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return MemoryImage(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CroppedImageProvider trims blank margins', (tester) async {
    await tester.runAsync(() async {
      final source = await _png(margins: true);
      final image = await _resolve(CroppedImageProvider(source));
      expect(image.width, 80);
      expect(image.height, 80);
    });
  });

  testWidgets('CroppedImageProvider keeps full-bleed images intact', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await _png(margins: false);
      final image = await _resolve(CroppedImageProvider(source));
      expect(image.width, 100);
      expect(image.height, 100);
    });
  });

  test('comicAutoCrop persists and defaults to off', () async {
    expect(const ReaderSettings().comicAutoCrop, isFalse);
    await ReaderKv.useMemoryForTesting();
    await ReaderSettingsStore.instance.save(
      const ReaderSettings(comicAutoCrop: true),
    );
    final loaded = await ReaderSettingsStore.instance.load();
    expect(loaded?.comicAutoCrop, isTrue);
  });
}
