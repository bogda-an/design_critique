import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the actual root widget from your app
import 'package:design_critique/main.dart' show DesignCritiqueApp;

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const DesignCritiqueApp()); // remove const if needed
    // Make a simple, true assertion that doesn’t rely on the counter template:
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
