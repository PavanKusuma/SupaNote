import 'package:flutter_test/flutter_test.dart';
import 'package:supa_note/main.dart';

void main() {
  testWidgets('App launches with SupaNote title', (WidgetTester tester) async {
    await tester.pumpWidget(const SupaNoteApp());
    expect(find.text('SupaNote'), findsOneWidget);
    expect(find.text('Capture your thoughts'), findsOneWidget);
  });
}
