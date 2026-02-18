// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:estou_aqui/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows app title', (WidgetTester tester) async {
    // Pump only the SplashScreen to avoid initializing platform WebView in tests.
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SplashScreen())));

    // Let the SplashScreen timer run and settle (it waits 2s before checking auth).
    await tester.pump(const Duration(seconds: 3));

    // The splash contains the text 'Estou Aqui'.
    expect(find.text('Estou Aqui'), findsOneWidget);
  });
}
