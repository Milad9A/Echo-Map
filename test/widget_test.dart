import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders successfully', (WidgetTester tester) async {
    // Verify the app title appears somewhere
    expect(find.text('EchoMap'), findsOneWidget);

    // Verify the welcome message on the home screen
    expect(find.text('Welcome to EchoMap'), findsOneWidget);

    // Test navigation to vibration test screen
    await tester.tap(find.text('Vibration Test'));
    await tester.pumpAndSettle();

    // Verify we're on the vibration test screen
    expect(find.text('Vibration Pattern Tester'), findsOneWidget);
  });
}
