import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phantasm_read_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shows reader entries', (WidgetTester tester) async {
    await tester.pumpWidget(const PhantasmReadExampleApp());
    expect(find.text('漫画阅读器'), findsOneWidget);
    expect(find.text('小说阅读器（文本）'), findsOneWidget);
  });
}
