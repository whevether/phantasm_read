import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_lifecycle.dart';

class ProbeBrightness extends ReaderBrightness {
  final values = <double>[];
  Completer<void>? gate;
  bool closed = false;
  @override
  Future<void> apply(double value) async {
    values.add(value);
    await gate?.future;
  }

  @override
  Future<void> restore() async {}
  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Closing a nested reader restores the previous session', () async {
    final a = ProbeBrightness(), b = ProbeBrightness();
    final first = ReaderSession(a), second = ReaderSession(b);
    addTearDown(() {
      second.dispose();
      first.dispose();
    });
    await first.apply(
      const ReaderSettings(
        brightness: 0.4,
        keepScreenOn: false,
        immersive: false,
      ),
    );
    await second.apply(
      const ReaderSettings(
        brightness: 0.7,
        keepScreenOn: false,
        immersive: false,
      ),
    );
    second.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(a.values, [0.4, 0.4]);
    expect(b.closed, isTrue);
    first.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(a.closed, isTrue);
  });
  test(
    'Dispose during pending display effects releases resources in order',
    () async {
      final brightness = ProbeBrightness()..gate = Completer<void>();
      final session = ReaderSession(brightness);
      final applying = session.apply(const ReaderSettings());
      await Future<void>.delayed(Duration.zero);
      session.dispose();
      brightness.gate!.complete();
      await applying;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(brightness.closed, isTrue);
    },
  );
}
