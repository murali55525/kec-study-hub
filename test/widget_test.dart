// widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart'; // Ensure this matches your project structure

void main() {
  testWidgets('LoginPage UI test', (WidgetTester tester) async {
    // Build the app with required parameters
    await tester.pumpWidget(const KECStudyHubApp(
      isDarkMode: false,
      deviceId: 'test-device-id',
    ));

    // Trigger a frame to ensure the widget tree is built
    await tester.pump();

    // Verify that the LoginPage loads with expected widgets
    expect(find.text('KEC Study Hub'), findsOneWidget); // Title text in body
    expect(
        find.text('Sign in to your account'), findsOneWidget); // Subtitle text
    expect(
        find.byType(TextField), findsNWidgets(2)); // Email and Password fields
    expect(find.text('Email'), findsOneWidget); // Email label
    expect(find.text('Password'), findsOneWidget); // Password label
    expect(find.text('Login'), findsOneWidget); // Login button text
    expect(find.byIcon(Icons.email), findsOneWidget); // Email prefix icon
    expect(find.byIcon(Icons.lock), findsOneWidget); // Password prefix icon

    // Simulate entering text into the email field
    await tester.enterText(find.byType(TextField).first, 'test@kongu.edu');
    await tester.pump();

    // Verify the email field now contains the entered text
    expect(find.widgetWithText(TextField, 'test@kongu.edu'), findsOneWidget);

    // Simulate entering text into the password field
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.pump();

    // Verify the password field now contains the entered text
    expect(find.widgetWithText(TextField, 'password123'), findsOneWidget);

    // Simulate tapping the Login button
    await tester.tap(find.text('Login'));
    await tester.pump();

    // Since we can't mock HTTP in this simple test, we expect the SnackBar for invalid credentials
    // Note: This assumes no backend mocking; actual behavior depends on backend response
    // For a full test, you'd need to mock the HTTP client (beyond this scope)
    expect(
        find.byType(SnackBar), findsNothing); // No SnackBar yet without mocking
  });
}
