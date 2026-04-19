import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mysolat/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Your root widget is MySolatApp (not MyApp)
    await tester.pumpWidget(const MySolatApp());

    // Just a basic smoke test: app builds without crashing
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}