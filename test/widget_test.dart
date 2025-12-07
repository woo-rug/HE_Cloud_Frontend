// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_cloud_frontend/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders core widgets', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('HE Cloud'), findsOneWidget);
    expect(find.textContaining('Demo 계정'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('아직 계정이 없나요? 회원가입'), findsOneWidget);
  });
}
