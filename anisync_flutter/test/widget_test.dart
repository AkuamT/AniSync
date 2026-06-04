import 'package:flutter_test/flutter_test.dart';
import 'package:anisync/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AniSyncApp());
    expect(find.text('AniSync'), findsOneWidget);
  });
}
