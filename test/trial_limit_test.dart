import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/src/common/reader_page_window.dart';
import 'package:phantasm_read/src/common/reader_trial_limit.dart';
import 'package:phantasm_read/src/common/trial_gesture_boundary.dart';

void main() {
  group('ReaderTrialLimit', () {
    test('basic window from the start', () {
      final l = ReaderTrialLimit.pages(3);
      expect(l.visibleCount(10), 3);
      expect(l.maxReadableIndex(10), 2);
      expect(l.hasMoreBeyond(10), isTrue);
      expect(l.isReadable(2, 10), isTrue);
      expect(l.isReadable(3, 10), isFalse);
      expect(l.isReadable(-1, 10), isFalse);
      expect(l.atBoundary(2, 10), isTrue);
      expect(l.atBoundary(1, 10), isFalse);
      expect(l.clampIndex(9, 10), 2);
      expect(l.clampIndex(-5, 10), 0);
    });

    test('window with offset start', () {
      final l = ReaderTrialLimit.pages(3, startPage: 5);
      expect(l.visibleCount(10), 3);
      expect(l.isReadable(4, 10), isFalse);
      expect(l.isReadable(5, 10), isTrue);
      expect(l.isReadable(7, 10), isTrue);
      expect(l.isReadable(8, 10), isFalse);
      expect(l.clampIndex(0, 10), 5);
      expect(l.clampIndex(9, 10), 7);
    });

    test('window larger than content is not limited', () {
      final l = ReaderTrialLimit.pages(20);
      expect(l.visibleCount(10), 10);
      expect(l.hasMoreBeyond(10), isFalse);
      expect(l.atBoundary(9, 10), isFalse);
    });

    test('startIndex beyond total exposes nothing readable', () {
      final l = ReaderTrialLimit.pages(3, startPage: 12);
      expect(l.visibleCount(10), 0);
      for (var i = 0; i < 10; i++) {
        expect(l.isReadable(i, 10), isFalse);
      }
    });

    test('maxCount <= 0 is documented as unlimited (host must validate)', () {
      final l = ReaderTrialLimit.pages(0);
      expect(l.isActive, isFalse);
      expect(l.visibleCount(10), 10);
    });
  });

  group('ReaderPageWindow', () {
    test('single page mapping', () {
      final w = ReaderPageWindow(
        10,
        trial: ReaderTrialLimit.pages(3, startPage: 2),
      );
      expect(w.start, 2);
      expect(w.count, 3);
      expect(w.content(1), 3);
      expect(w.logical(4), 2);
      expect(w.readable(1), isFalse);
      expect(w.readable(2), isTrue);
    });

    test('double page mapping rounds up', () {
      final w = ReaderPageWindow(
        10,
        trial: ReaderTrialLimit.pages(3, startPage: 2),
        doublePage: true,
      );
      expect(w.count, 2);
      expect(w.content(1), 4);
    });
  });

  group('TrialGestureNotifier', () {
    test('debounces repeated triggers', () {
      final n = TrialGestureNotifier();
      var calls = 0;
      void fire() => n.call(
        (_) => calls++,
        limit: ReaderTrialLimit.pages(3),
        currentIndex: 2,
        targetIndex: 3,
        totalCount: 10,
        action: ReaderTrialLimitAction.next,
      );
      fire();
      fire();
      expect(calls, 1);
    });

    test('inactive limit never fires', () {
      final n = TrialGestureNotifier();
      var calls = 0;
      n.call(
        (_) => calls++,
        limit: ReaderTrialLimit.pages(0),
        currentIndex: 0,
        targetIndex: 1,
        totalCount: 10,
        action: ReaderTrialLimitAction.next,
      );
      expect(calls, 0);
    });
  });
}
