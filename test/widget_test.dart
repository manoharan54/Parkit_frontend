import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:parkit_flutter/main.dart';

void main() {
  testWidgets('login screen loads with validation fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen(onAuthenticated: _noop)));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signup screen exposes all account fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen(onCreated: _noop)));
    await tester.pump();

    expect(find.text('Your parking profile'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Vehicle number'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });
}

void _noop() {}
