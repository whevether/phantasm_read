import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';

void main() {
  Widget host(List<int> seen, {int initialIndex = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: ComicWebtoonView(
          count: 10,
          initialIndex: initialIndex,
          onIndexChanged: seen.add,
          itemBuilder: (i) => SizedBox(height: 400, child: Text('page $i')),
        ),
      ),
    );
  }

  testWidgets('scrolling reports increasing center index', (tester) async {
    final seen = <int>[];
    await tester.pumpWidget(host(seen));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    expect(seen, isNotEmpty);
    expect(seen.last, greaterThan(0));
  });

  testWidgets('scrolling back reports a smaller index', (tester) async {
    final seen = <int>[];
    await tester.pumpWidget(host(seen));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final forward = seen.last;
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();

    expect(seen.last, lessThan(forward));
  });
}
