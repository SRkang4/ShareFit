import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/widgets/google_sign_in_button.dart';

void main() {
  testWidgets('shows the official logo and invokes the Google login action', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(
            isLoading: false,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Google로 계속하기'));
    expect(pressed, isTrue);
  });

  testWidgets('disables duplicate taps while Google login is loading', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(isLoading: true, onPressed: () => presses++),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    expect(presses, 0);
  });
}
