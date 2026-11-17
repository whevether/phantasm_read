import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';

void main() {
  test('ReaderStatsTracker counts distinct visits only', () {
    final t = ReaderStatsTracker('book');
    t.visit(1, chars: 10);
    t.visit(1, chars: 10);
    t.visit(2, chars: 5);
    final s = t.snapshot();
    expect(s.pagesRead, 2);
    expect(s.charsRead, 15);
    expect(ReaderStats.fromJson(s.toJson()).pagesRead, 2);
  });

  test('ChineseTextConverter round-trips common characters', () {
    expect(ChineseTextConverter.toTraditional('这个学'), '這個學');
    expect(ChineseTextConverter.toSimplified('這個學'), '这个学');
    expect(ChineseTextConverter.toTraditional('abc'), 'abc');
  });

  test('ComicAutoCrop detects blank margins and keeps full on empty', () {
    const w = 10, h = 10;
    final px = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      px[i * 4] = 255;
      px[i * 4 + 1] = 255;
      px[i * 4 + 2] = 255;
      px[i * 4 + 3] = 255;
    }
    for (var y = 3; y < 7; y++) {
      for (var x = 3; x < 7; x++) {
        final i = (y * w + x) * 4;
        px[i] = 0;
        px[i + 1] = 0;
        px[i + 2] = 0;
      }
    }
    final r = ComicAutoCrop.detect(px, w, h, maxCrop: 0.5);
    expect(r.left, closeTo(0.3, 1e-9));
    expect(r.top, closeTo(0.3, 1e-9));
    expect(r.right, closeTo(0.7, 1e-9));
    expect(r.bottom, closeTo(0.7, 1e-9));
    expect(ComicAutoCrop.detect(Uint8List(0), w, h).isFull, isTrue);
  });

  test('ReaderStrings presets differ', () {
    expect(ReaderStrings.zh.bookmarks, isNot(ReaderStrings.en.bookmarks));
  });
}
