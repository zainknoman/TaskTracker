import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasktracker_flutter/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders email, password fields and sign-in button', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
