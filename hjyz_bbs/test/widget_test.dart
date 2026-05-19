import 'package:flutter_test/flutter_test.dart';
import 'package:hjyz_bbs/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ForumXApp());
    expect(find.text('ForumX Lite'), findsOneWidget);
  });
}
