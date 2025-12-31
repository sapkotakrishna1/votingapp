import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evoting_app/main.dart';

void main() {
  testWidgets('E-Voting app loads Login Screen', (WidgetTester tester) async {
    // Load the main application
    await tester.pumpWidget(const MyApp());

    // Check if LoginScreen UI exists
    expect(find.byType(TextField), findsWidgets); // At least one text field
    expect(find.text("Login"), findsOneWidget); // Login button or label
  });
}
